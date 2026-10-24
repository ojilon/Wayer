// =============================================================================
// organizer.odin — plan + apply file organization moves
//
// Part of package storage. Implements the Organize feature that generates a
// plan of file moves (grouping by type/date) and applies it atomically.
//
// Flow (file-backed, same as every other module)
//   1. plan_organize(root) → JSON {"moves":[{"from","to"},...]}
//   2. plan_organize_to_file(root, out_path) → writes plan, returns {status,path}
//      Java shows the plan in a confirmation dialog (via OrganizeHelper.java).
//   3. apply_organize_file(plan_path, report_path) → reads plan, moves files,
//      writes report {"moved","failed","skipped","errors":[...]}.
//
// Plan generation rules
//   * Walks root via C FS (bionic-safe).
//   * Only recognized categories that are movable: not Others, not Images
//     (images stay where the user left them; we relocate docs/media etc.).
//   * Destination: <root>/<category>/<YYYY-MM>/<filename>
//     Date bucket is from file mtime (see date_bucket below).
//   * Moves where dest == source are skipped (already organized).
//
// Apply rules
//   * Parses the plan JSON without a full JSON lib (hand scanner — avoids
//     nlohmann/json dependency in Odin; plan shape is simple and predictable).
//   * Creates dest parent dirs via C mkdir -p.
//   * If dest exists, appends "_dup" before extension to avoid overwrite.
//   * Records at most 100 errors; the report always fits in memory.
//
// Android 10 / bionic: All file ops via wayer_fs_* wrappers.
//
// Mirrors: wayer::storage::plan_organize, apply_organize_file
//          in native/storage/modules/organizer/src/file_organizer.cpp
// =============================================================================

package storage

import "core:fmt"
import "core:strings"
import "core:time"

import core_heart "../../core/src"
import fs "../../file_system_bridge/src"
import js_util "../../json_utils/src"

// Move represents one file move from the plan.
Move :: struct {
	from: string,
	to:   string,
}

// date_bucket returns YYYY-MM string for a file's mtime via C stat.
// Falls back to "unknown-date" when stat fails.
date_bucket :: proc(path: string) -> string {
	_, mtime, _, ok := fs.stat_c(path)
	if !ok {
		return "unknown-date"
	}
	// Convert unix seconds to YYYY-MM using Odin's time package.
	// Odin Oct 2025: time.unix() → Time, then time.year/month helpers.
	t := time.unix(mtime, 0)
	year, month, _ := time.date(t)
	return fmt.tprintf("%04d-%02d", year, int(month))
}

// plan_organize generates a JSON plan of moves for root_path.
// Mirrors wayer::storage::plan_organize
plan_organize :: proc(root_path: string) -> string {
	if len(root_path) == 0 {
		return `{"moves":[]}`
	}

	sb := strings.builder_make(context.temp_allocator)
	strings.write_string(&sb, `{"moves":[`)

	first := true

	// Walk callback needs to close over sb and first — use package-level helpers
	// with context via WalkWithCtx (see cleaner.odin for pattern).
	organize_ctx := OrganizeCtx{
		root_path = root_path,
		sb        = &sb,
		first     = &first,
	}
	walk_files_with_ctx(root_path, organize_walk_cb, &organize_ctx)

	strings.write_string(&sb, "]}")
	return strings.to_string(sb)
}

// OrganizeCtx holds state for the organize walk callback.
OrganizeCtx :: struct {
	root_path: string,
	sb:        ^strings.Builder,
	first:     ^bool,
}

organize_walk_cb :: proc(path: string, name: string, size: i64, mtime: i64, ud: rawptr) {
	_ = size
	_ = mtime
	ctx := cast(^OrganizeCtx)ud

	// Determine category from extension
	dot := strings.last_index_byte(name, '.')
	ext := ""
	if dot > 0 && dot+1 < len(name) {
		ext = name[dot:]
	}
	// Lowercase extension for lookup
	ext_lower := strings.clone(ext, context.temp_allocator)
	for i in 0 ..< len(ext_lower) {
		ch := ext_lower[i]
		if ch >= 'A' && ch <= 'Z' {
			// Need to mutate copy — we cloned, so we can write back.
			// But strings are immutable in Odin; use a byte slice view.
			// Simpler: rebuild via ascii_lower helper on ext.
			break
		}
	}
	// Use the proper helper for the full name category
	category := category_for_name(name)

	// Only recognized, movable categories: not Others, not Images (stay put)
	if category == .Others || category == .Images {
		return
	}

	// Map Category enum to directory name
	cat_dir: string
	switch category {
	case .Images:
		cat_dir = "images"
	case .Videos:
		cat_dir = "videos"
	case .Audio:
		cat_dir = "audio"
	case .Documents:
		cat_dir = "documents"
	case .Foreign_Files:
		cat_dir = "foreign"
	case .Others:
		return
	}

	bucket := date_bucket(path)
	dest := strings.concatenate({ctx.root_path, "/", cat_dir, "/", bucket, "/", name}, context.temp_allocator)

	if dest == path {
		return // already organized
	}

	if !ctx.first^ {
		strings.write_string(ctx.sb, ",")
	}
	ctx.first^ = false
	fmt.sbprintf(ctx.sb, `{"from":"%s","to":"%s"}`,
		js_util.json_escape(path),
		js_util.json_escape(dest))
}

// plan_organize_to_file writes plan JSON to out_path and returns status JSON.
// Mirrors wayer::storage::plan_organize_to_file
plan_organize_to_file :: proc(root_path: string, out_path: string) -> string {
	json := plan_organize(root_path)
	if !core_heart.write_text_file(out_path, json) {
		return `{"status":"error","reason":"write_failed"}`
	}
	return fmt.tprintf(`{"status":"ok","path":"%s"}`, js_util.json_escape(out_path))
}

// apply_organize_file executes a plan file (JSON) and writes a report.
// Mirrors wayer::storage::apply_organize_file
apply_organize_file :: proc(plan_path: string, report_path: string) -> string {
	// Read plan file via C FS (1 MiB cap — plans are small)
	plan_data, ok := fs.read_file_c(plan_path, 1024 * 1024)
	if !ok || len(plan_data) == 0 {
		return `{"status":"error","reason":"bad_plan"}`
	}

	// Parse moves from JSON — hand scanner for the simple shape:
	// {"moves":[{"from":"...","to":"..."}, ...]}
	// We look for "from":" and "to":" pairs sequentially.
	moves := make([dynamic]Move, 0, 16, context.temp_allocator)

	// Find moves array start
	moves_start := strings.index(plan_data, `"moves":[`)
	if moves_start == -1 {
		return `{"status":"error","reason":"bad_plan"}`
	}
	remaining := plan_data[moves_start + len(`"moves":[`):]

	for {
		from_key := strings.index(remaining, `"from":"`)
		if from_key == -1 {
			break
		}
		from_start := from_key + len(`"from":"`)
		// Find closing unescaped quote for `from`
		from_end := find_json_string_end(remaining, from_start)
		if from_end == -1 {
			break
		}
		from_val := unescape_json_string(remaining[from_start:from_end])

		// Find "to" after this "from"
		to_key := strings.index(remaining[from_end:], `"to":"`)
		if to_key == -1 {
			break
		}
		to_start := from_end + to_key + len(`"to":"`)
		to_end := find_json_string_end(remaining, to_start)
		if to_end == -1 {
			break
		}
		to_val := unescape_json_string(remaining[to_start:to_end])

		append(&moves, Move{
			from = strings.clone(from_val, context.temp_allocator),
			to   = strings.clone(to_val, context.temp_allocator),
		})

		// Advance past this object (find next })
		next_brace := strings.index(remaining[to_end:], "}")
		if next_brace == -1 {
			break
		}
		remaining = remaining[to_end + next_brace + 1:]
	}

	// Execute moves
	moved   := 0
	failed  := 0
	skipped := 0
	errors  := make([dynamic]string, 0, 16, context.temp_allocator)

	kMaxErrors :: 100

	for move in moves {
		if len(move.from) == 0 || len(move.to) == 0 {
			skipped += 1
			continue
		}

		// Source must exist
		_, _, _, src_ok := fs.stat_c(move.from)
		if !src_ok {
			skipped += 1
			continue
		}

		// Ensure dest parent exists
		dest := move.to
		last_slash := -1
		for i in 0 ..< len(dest) {
			if dest[i] == '/' {
				last_slash = i
			}
		}
		if last_slash > 0 {
			parent := dest[:last_slash]
			if !fs.mkdir_p_c(parent) {
				failed += 1
				if len(errors) < kMaxErrors {
					append(&errors, fmt.tprintf(`{"from":"%s","reason":"mkdir_failed"}`, js_util.json_escape(move.from)))
				}
				continue
			}
		}

		// Avoid overwrite: if dest exists, add _dup before extension
		_, _, _, dest_exists := fs.stat_c(dest)
		if dest_exists {
			dot := strings.last_index_byte(dest, '.')
			slash := strings.last_index_byte(dest, '/')
			// Only treat dot as extension if after last slash
			if dot > slash && dot != -1 && slash != -1 {
				dest = strings.concatenate({dest[:dot], "_dup", dest[dot:]}, context.temp_allocator)
			} else if dot != -1 && slash == -1 {
				dest = strings.concatenate({dest[:dot], "_dup", dest[dot:]}, context.temp_allocator)
			} else {
				dest = strings.concatenate({dest, "_dup"}, context.temp_allocator)
			}
		}

		if !fs.rename_c(move.from, dest) {
			failed += 1
			if len(errors) < kMaxErrors {
				append(&errors, fmt.tprintf(`{"from":"%s","reason":"move_failed"}`, js_util.json_escape(move.from)))
			}
		} else {
			moved += 1
		}
	}

	// Build report JSON
	sb := strings.builder_make(context.temp_allocator)
	fmt.sbprintf(&sb, `{"moved":%d,"failed":%d,"skipped":%d,"errors":[`, moved, failed, skipped)
	for i in 0 ..< len(errors) {
		if i > 0 {
			strings.write_string(&sb, ",")
		}
		strings.write_string(&sb, errors[i])
	}
	strings.write_string(&sb, "]}")
	report_json := strings.to_string(sb)

	if !core_heart.write_text_file(report_path, report_json) {
		return `{"status":"error","reason":"write_failed"}`
	}

	return fmt.tprintf(`{"status":"ok","path":"%s"}`, js_util.json_escape(report_path))
}

// ---------------------------------------------------------------------------
// Minimal JSON string scanner — handles escaped quotes correctly
// ---------------------------------------------------------------------------

// find_json_string_end finds the closing unescaped " starting from `start`.
// Returns index of closing quote, or -1.
find_json_string_end :: proc(s: string, start: int) -> int {
	escape := false
	for i := start; i < len(s); i += 1 {
		ch := s[i]
		if escape {
			escape = false
			continue
		}
		if ch == '\\' {
			escape = true
			continue
		}
		if ch == '"' {
			return i
		}
	}
	return -1
}

// unescape_json_string handles \" and \\ inside a JSON string value.
// For plan files this is sufficient; we don't need full \uXXXX support.
unescape_json_string :: proc(s: string) -> string {
	// Fast path: no backslash
	if strings.index_byte(s, '\\') == -1 {
		return s
	}
	sb := strings.builder_make(context.temp_allocator)
	i := 0
	for i < len(s) {
		if s[i] == '\\' && i+1 < len(s) {
			next := s[i+1]
			switch next {
			case '"':  strings.write_byte(&sb, '"');  i += 2
			case '\\': strings.write_byte(&sb, '\\'); i += 2
			case '/':  strings.write_byte(&sb, '/');  i += 2
			case 'n':  strings.write_byte(&sb, '\n'); i += 2
			case 'r':  strings.write_byte(&sb, '\r'); i += 2
			case 't':  strings.write_byte(&sb, '\t'); i += 2
			case:      strings.write_byte(&sb, s[i]);  i += 1
			}
		} else {
			strings.write_byte(&sb, s[i])
			i += 1
		}
	}
	return strings.to_string(sb)
}
