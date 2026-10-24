// =============================================================================
// preview.odin — capped read-only text file preview
//
// Part of package preview (wayer_preview). Serves DocumentActivity's text
// viewer: read up to N bytes of a file, sniff for binary (NUL byte → refuse),
// split into lines, and return a capped JSON document.
//
// Limits (do not raise — mobile memory constrained)
//   default 64 KiB → caller passes 0 to get default
//   hard cap 256 KiB → larger requests are clamped, never trusted
//
// Output shapes (what Java parses)
//   Text:   {"path":"...","size":12345,"truncated":false,"line_count":3,"lines":["a","b","c"]}
//   Binary: {"path":"...","size":12345,"binary":true}
//   Error:  {"error":"not_found"} | "not_file" | "unreadable"
//
// Why Odin for this?
//   * Preview is read-only; a pure string operation is trivial in Odin.
//   * No SQLite/JSON lib needed — just line split + escape.
//   * File read uses the bionic-safe C wrapper (no statx).
//
// Mirrors: wayer::preview::read_text_file in preview.cpp / preview.hpp
// =============================================================================

package preview

import "core:fmt"
import "core:strings"

import core_heart "../../core/src"
import js_util "../../json_utils/src"
import fs "../../file_system_bridge/src"

kDefaultMaxBytes :: u64(64 * 1024)  // 64 KiB default
kHardMaxBytes    :: u64(256 * 1024) // 256 KiB hard cap — never exceed

// read_text_file reads up to max_bytes of a text file and returns preview JSON.
// Mirrors wayer::preview::read_text_file
read_text_file :: proc(path: string, max_bytes: u64) -> string {
	limit := max_bytes
	if limit == 0 {
		limit = kDefaultMaxBytes
	}
	if limit > kHardMaxBytes {
		limit = kHardMaxBytes
	}

	if len(path) == 0 {
		return `{"error":"not_found"}`
	}

	// Stat via C wrapper (bionic-safe) — check existence + is_file
	size, _, is_dir, ok := fs.stat_c(path)
	if !ok {
		return `{"error":"not_found"}`
	}
	if is_dir {
		return `{"error":"not_file"}`
	}

	// Read via C wrapper (capped at limit)
	data, ok2 := fs.read_file_c(path, int(limit))
	if !ok2 {
		return `{"error":"unreadable"}`
	}
	buf := transmute([]u8)data

	// Binary sniff: NUL byte means "not text" (common for images/pdf/zip)
	for b in buf {
		if b == 0 {
			return fmt.tprintf(`{"path":"%s","size":%d,"binary":true}`,
				js_util.json_escape(path), size)
		}
	}

	// Convert to string for line splitting
	text := string(buf)

	// Split on \n (tolerate \r\n by stripping trailing \r per line)
	lines_builder := strings.builder_make(context.temp_allocator)
	line_count := 0
	start := 0
	first_line := true

	for start <= len(text) {
		// Find next newline
		end_rel := strings.index(text[start:], "\n")
		last := false
		end_abs: int
		if end_rel == -1 {
			last = true
			end_abs = len(text)
		} else {
			end_abs = start + end_rel
		}

		line := text[start:end_abs]
		// Strip trailing \r (for \r\n lines)
		if len(line) > 0 && line[len(line)-1] == '\r' {
			line = line[:len(line)-1]
		}

		if !first_line {
			strings.write_string(&lines_builder, ",")
		}
		first_line = false
		fmt.sbprintf(&lines_builder, `"%s"`, js_util.json_escape(line))
		line_count += 1

		if last {
			break
		}
		start = end_abs + 1
	}

	truncated := i64(size) > i64(limit)
	lines_json := strings.to_string(lines_builder)

	return fmt.tprintf(
		`{"path":"%s","size":%d,"truncated":%s,"line_count":%d,"lines":[%s]}`,
		js_util.json_escape(path), size,
		js_util.bool_to_string(truncated), line_count, lines_json)
}
