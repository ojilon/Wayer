// =============================================================================
// cleaner.odin — large-file finder + duplicate detector
//
// Part of package storage (wayer_cleaner). This is the Odin port of the two
// Cleaner utilities: Large Files and Duplicates. Both use the bionic-safe
// C FS walk (fs_android.odin) and produce file-backed JSON so JNI stays small.
//
// Utilities
//   find_large_files      — top N largest files ≥ min_bytes, sorted descending
//   find_duplicates       — byte-identical groups + related-file display groups
//
// File-backed variants (what Java calls)
//   find_large_files_to_file — writes {"min_bytes","count","files":[...]}
//   find_duplicates_to_file  — writes {"version":2,"duplicate_groups":[[...]],...}
//
// Hash strategy for duplicates (three-stage, same as C++)
//   1. Group by size (cheap — from directory walk)
//   2. Within equal-size groups, group by partial hash (first 4 KiB + size mix)
//   3. Confirm collisions by full FNV-1a hash + byte-equal verification
//   Only genuine byte-identical files become a duplicate group. Hash is just a
//   fast filter; we never trust it alone.
//
// Related files
//   Display-only heuristic: normalize file names (strip " (1)", " copy",
//   " final", "_v2", etc.) and group those sharing a key. Helps users spot
//   manual versions even when bytes differ.
//
// Android 10 / bionic
//   * All file reads via fs_android read_file_c → wayer_fs_read_file (open/read)
//   * Hash uses FNV-1a (no external crypto lib needed; fast on mobile)
//   * Sorting via core:slice / core:sort equivalents (Odin Oct 2025)
//
// Mirrors: wayer::storage::find_large_files, find_duplicates
//          in native/storage/modules/cleaner/src/*
// =============================================================================

package storage

import "core:c"
import "core:fmt"
import "core:mem"
import "core:slice"
import "core:strings"
import "base:runtime"

import core_heart "../../core/src"
import fs "../../file_system_bridge/src"
import js_util "../../json_utils/src"

// =============================================================================
// LARGE FILES
// =============================================================================

LargeEntry :: struct {
	name: string,
	path: string,
	size: u64,
}

// find_large_files returns JSON with top N largest files ≥ min_bytes.
// Mirrors wayer::storage::find_large_files
find_large_files :: proc(root_path: string, min_bytes: u64, max_results: int) -> string {
	mb := min_bytes
	if mb == 0 {
		mb = 10 * 1024 * 1024 // default 10 MiB
	}
	limit := max_results
	if limit <= 0 {
		limit = 50
	}

	// Need to capture limit/mb for closure — use context for walk callback.
	// We use a dynamic array on temp_allocator; freed per JNI call.
	found := make([dynamic]LargeEntry, 0, 64, context.temp_allocator)

	// Walk via C FS — collect files meeting size threshold.
	// We use a manual walk with closure workaround (see WalkCtx pattern).
	// Simplified: collect via global-ish dynamic inside temp_allocator by
	// using a context value. For this proc we use a package-level trick:
	// store the slice pointer in context.user_ptr for the callback.
	//
	// Alternative (simpler): do walk inline and append directly.
	//
	// Because Odin's walk_files_c takes a proc value (not closure), we need to
	// use a trampoline with external state. We'll use a package-level buffer.

	// Use a helper that wraps walk_files_c with a closure-like pattern via context value.
	large_accum_ctx := LargeAccum{
		min_bytes = mb,
		found     = &found,
	}
	walk_files_with_ctx(root_path, large_walk_cb, &large_accum_ctx)

	// Sort descending by size
	slice.sort_by(found[:], proc(a, b: LargeEntry) -> bool {
		return a.size > b.size
	})

	want := min(limit, len(found))
	top := found[:want]

	// Build JSON
	sb := strings.builder_make(context.temp_allocator)
	fmt.sbprintf(&sb, `{"min_bytes":%d,"count":%d,"files":[`, mb, len(top))

	for i in 0 ..< len(top) {
		if i > 0 {
			strings.write_string(&sb, ",")
		}
		e := top[i]
		fmt.sbprintf(&sb, `{"name":"%s","path":"%s","size":%d}`,
			js_util.json_escape(e.name),
			js_util.json_escape(e.path),
			e.size)
	}

	strings.write_string(&sb, "]}")
	return strings.to_string(sb)
}

// LargeAccum is the context for large-file walk callback (replaces lambda capture).
LargeAccum :: struct {
	min_bytes: u64,
	found:    ^[dynamic]LargeEntry,
}

large_walk_cb :: proc(path: string, name: string, size: i64, mtime: i64, ud: rawptr) {
	_ = mtime
	ctx := cast(^LargeAccum)ud
	if size < i64(ctx.min_bytes) {
		return
	}
	append(ctx.found, LargeEntry{
		name = strings.clone(name, context.temp_allocator),
		path = strings.clone(path, context.temp_allocator),
		size = u64(size),
	})
}

// find_large_files_to_file writes results to file and returns status JSON.
// Mirrors wayer::storage::find_large_files_to_file
find_large_files_to_file :: proc(root_path: string, min_bytes: u64, max_results: int, out_path: string) -> string {
	json := find_large_files(root_path, min_bytes, max_results)
	if !core_heart.write_text_file(out_path, json) {
		return `{"status":"error","reason":"write_failed"}`
	}
	return fmt.tprintf(`{"status":"ok","path":"%s"}`, js_util.json_escape(out_path))
}

// =============================================================================
// DUPLICATES
// =============================================================================

DupFile :: struct {
	path:  string,
	size:  u64,
	mtime: i64, // unix seconds, 0 = unknown
}

// ---------------------------------------------------------------------------
// Hash helpers — FNV-1a 64-bit (no crypto dependency, fast on mobile)
// ---------------------------------------------------------------------------

FNV_OFFSET :: u64(14695981039346656037)
FNV_PRIME  :: u64(1099511628211)

// fnv1a_bytes hashes len bytes via FNV-1a.
fnv1a_bytes :: proc(data: []u8) -> u64 {
	h := FNV_OFFSET
	for b in data {
		h = h ~ u64(b)
		h *= FNV_PRIME
	}
	return h
}

// try_partial_hash computes hash of first 4 KiB mixed with file size.
// Returns (hash, success). Uses C FS read (bionic-safe).
try_partial_hash :: proc(path: string, size: u64) -> (u64, bool) {
	data, ok := fs.read_file_c(path, 4096)
	if !ok {
		return 0, false
	}
	h := fnv1a_bytes(transmute([]u8)data)
	h = h ~ (size * 0x9E3779B97F4A7C15)
	return h, true
}

// try_full_hash computes full FNV-1a hash of file.
try_full_hash :: proc(path: string) -> (u64, bool) {
	data, ok := fs.read_file_c(path, 16 * 1024 * 1024) // cap 16 MiB for hashing
	if !ok {
		return 0, false
	}
	h := fnv1a_bytes(transmute([]u8)data)
	return h, true
}

// files_byte_equal compares two files byte-for-byte via C FS reads.
files_byte_equal :: proc(a: string, b: string) -> bool {
	data_a, ok_a := fs.read_file_c(a, 16 * 1024 * 1024)
	if !ok_a {
		return false
	}
	data_b, ok_b := fs.read_file_c(b, 16 * 1024 * 1024)
	if !ok_b {
		return false
	}
	if len(data_a) != len(data_b) {
		return false
	}
	return mem.compare(transmute([]u8)data_a, transmute([]u8)data_b) == 0
}

// file_mtime_unix returns mtime as unix seconds (0 = unknown).
file_mtime_unix :: proc(path: string) -> i64 {
	_, mtime, _, ok := fs.stat_c(path)
	if !ok {
		return 0
	}
	return mtime
}

// file_size_or_zero returns size or 0 on error.
file_size_or_zero :: proc(path: string) -> u64 {
	size, _, _, ok := fs.stat_c(path)
	if !ok {
		return 0
	}
	return u64(max(size, 0))
}

// ---------------------------------------------------------------------------
// Related-file normalization — strip version/copy suffixes for display grouping
// ---------------------------------------------------------------------------

ends_with_word :: proc(s: string, word: string) -> bool {
	if len(s) < len(word) {
		return false
	}
	return s[len(s)-len(word):] == word
}

trim_trailing_space_dash :: proc(s: string) -> string {
	end := len(s)
	
	for end > 0 {
		ch := s[end-1]
		if ch == ' ' || ch == '\t' || ch == '-' || ch == '_' || ch == '.' {
			end = end - 1
		} else {
			break
		}
	}

	//return the new slice 
	return s[:end]
}

// normalize_related_key strips " (1)", " copy", " final", " _v2" etc.
// Mirrors C++ normalize_related_key in duplicate_finder.cpp.
normalize_related_key :: proc(filename: string) -> string {
	lower := core_heart.ascii_lower(filename)
	dot := strings.last_index_byte(lower, '.')
	base := lower
	if dot > 0 {
		base = lower[:dot]
	}

	cur := strings.clone(base, context.temp_allocator)
	trimmed_cur := trim_trailing_space_dash(cur)

	for iter in 0..<5 {
		trimmed_cur = trim_trailing_space_dash(cur)
		if len(trimmed_cur) == 0 {
			break
		}

		// Trailing " (digits)" like " (1)" or "(12)"
		if len(trimmed_cur) > 0 && trimmed_cur[len(trimmed_cur)-1] == ')' {
			open := strings.last_index_byte(trimmed_cur, '(')
			if open != -1 && open + 1 < len(trimmed_cur) {
				all_digits := true
				for i := open + 1; i+1 < len(trimmed_cur); i += 1 {
					if trimmed_cur[i] < '0' || cur[i] > '9' {
						all_digits = false
						break
					}
				}
				if all_digits {
					cur = trimmed_cur[:open]
					continue
				}
			}
			break
		}

		if ends_with_word(trimmed_cur, "copy") {
			pos := len(trimmed_cur) - 4
			if pos > 0 {
				sep := trimmed_cur[pos-1]
				if sep == ' ' || sep == '-' || sep == '_' || sep == '(' {
					cur = trimmed_cur[:pos-1]
					continue
				}
			}
			break
		}

		if ends_with_word(trimmed_cur, "final") {
			pos := len(trimmed_cur) - 5
			if pos > 0 {
				sep := trimmed_cur[pos-1]
				if sep == ' ' || sep == '-' || sep == '_' {
					cur = trimmed_cur[:pos-1]
					continue
				}
			}
			break
		}

		// Trailing v-number: " v2", "_v2", "-v2"
		n := len(trimmed_cur)
		d := n
		for d > 0 && trimmed_cur[d-1] >= '0' && trimmed_cur[d-1] <= '9' {
			d -= 1
		}
		if d < n && d > 0 && (trimmed_cur[d-1] == 'v' || trimmed_cur[d-1] == 'V') {
			vpos := d - 1
			if vpos == 0 {
				cur = ""
				break
			}
			sep := trimmed_cur[vpos-1]
			if sep == ' ' || sep == '-' || sep == '_' || vpos == 0 {
				if vpos > 0 && (sep == ' ' || sep == '-' || sep == '_') {
					trimmed_cur = trimmed_cur[:vpos-1]
				} else {
					trimmed_cur = trimmed_cur[:vpos]
				}
				continue
			}
		}
		break
	}

	trimmed_cur2 := trim_trailing_space_dash(trimmed_cur)
	return trimmed_cur2
}

// ---------------------------------------------------------------------------
// find_duplicates — three-stage grouping + related display groups
// ---------------------------------------------------------------------------

// find_duplicates returns JSON with duplicate_groups and related_groups.
// Mirrors wayer::storage::find_duplicates
find_duplicates :: proc(root_path: string) -> string {
	// Stage 1: group by size (cheap — from walk)
	BySizeMap :: map[u64][dynamic]string
	by_size := make(BySizeMap, 64, context.temp_allocator)

	dup_walk_ctx := DupWalkCtx{by_size = &by_size}
	walk_files_with_ctx(root_path, dup_size_cb, &dup_walk_ctx)

	// Stage 2 & 3: partial hash → full hash → byte-equal verification
	duplicate_groups := make([dynamic][]DupFile, 0, 16, context.temp_allocator)

	for size, paths in by_size {
		if len(paths) < 2 {
			continue
		}

		by_partial := make(map[u64][dynamic]string, 16, context.temp_allocator)
		for path in paths {
			h, ok := try_partial_hash(path, size)
			if !ok {
				continue
			}
			list := by_partial[h]
			append(&list, strings.clone(path, context.temp_allocator))
			by_partial[h] = list
		}

		for _, candidates in by_partial {
			if len(candidates) < 2 {
				continue
			}

			by_full := make(map[u64][dynamic]string, 16, context.temp_allocator)
			for path in candidates {
				h, ok := try_full_hash(path)
				if !ok {
					continue
				}
				list := by_full[h]
				append(&list, strings.clone(path, context.temp_allocator))
				by_full[h] = list
			}

			for _, same_hash in by_full {
				if len(same_hash) < 2 {
					continue
				}

				// Hash is only a hint: split by real byte content.
				verified := make([dynamic][dynamic]string, 0, 4, context.temp_allocator)
				for path in same_hash {
					placed := false
					for i in 0 ..< len(verified) {
						group := verified[i]
						if len(group) > 0 && files_byte_equal(group[0], path) {
							append(&group, strings.clone(path, context.temp_allocator))
							verified[i] = group
							placed = true
							break
						}
					}
					if !placed {
						new_group := make([dynamic]string, 0, 2, context.temp_allocator)
						append(&new_group, strings.clone(path, context.temp_allocator))
						append(&verified, new_group)
					}
				}

				for v in verified {
					if len(v) < 2 {
						continue
					}
					group := make([dynamic]DupFile, 0, len(v), context.temp_allocator)
					for path in v {
						append(&group, DupFile{
							path  = strings.clone(path, context.temp_allocator),
							size  = size,
							mtime = file_mtime_unix(path),
						})
					}
					append(&duplicate_groups, group[:])
				}
			}
		}
	}

	// Sort groups for deterministic output
	for i in 0 ..< len(duplicate_groups) {
		g := duplicate_groups[i]
		slice.sort_by(g, proc(a, b: DupFile) -> bool { return a.path < b.path })
		duplicate_groups[i] = g
	}
	slice.sort_by(duplicate_groups[:], proc(a, b: []DupFile) -> bool {
		return a[0].path < b[0].path
	})

	// Related files: same normalized name, any size. Display-only.
	ByRelatedMap :: map[string][dynamic]string
	by_related := make(ByRelatedMap, 64, context.temp_allocator)

	for _, paths in by_size {
		for path in paths {
			// Basename: after last "/"
			slash := strings.last_index_byte(path, '/')
			fname := path
			if slash != -1 {
				fname = path[slash+1:]
			}
			if len(fname) == 0 {
				continue
			}
			key := normalize_related_key(fname)
			if len(key) < 3 {
				continue
			}
			// Need to handle map entry that may not exist yet
			existing, exists := by_related[key]
			if !exists {
				existing = make([dynamic]string, 0, 4, context.temp_allocator)
			}
			append(&existing, strings.clone(path, context.temp_allocator))
			by_related[strings.clone(key, context.temp_allocator)] = existing
		}
	}

	RelatedGroup :: struct {
		key:   string,
		files: []DupFile,
	}

	related := make([dynamic]RelatedGroup, 0, 16, context.temp_allocator)
	keys := make([dynamic]string, 0, 64, context.temp_allocator)
	for k, v in by_related {
		_ = v
		if len(by_related[k]) >= 2 && len(by_related[k]) <= 20 {
			append(&keys, k)
		}
	}
	slice.sort(keys[:])

	kMaxRelatedGroups    :: 200
	kMaxFilesPerRelated  :: 20

	for k in keys {
		if len(related) >= kMaxRelatedGroups {
			break
		}
		paths := by_related[k]
		slice.sort(paths[:])
		want := min(len(paths), kMaxFilesPerRelated)

		g := RelatedGroup{key = k}
		g.files = make([]DupFile, want, context.temp_allocator)
		for i in 0 ..< want {
			g.files[i] = DupFile{
				path  = strings.clone(paths[i], context.temp_allocator),
				size  = file_size_or_zero(paths[i]),
				mtime = file_mtime_unix(paths[i]),
			}
		}
		append(&related, g)
	}

	// Build JSON
	sb := strings.builder_make(context.temp_allocator)
	strings.write_string(&sb, `{"version":2,"duplicate_groups":[`)

	for gi in 0 ..< len(duplicate_groups) {
		if gi > 0 {
			strings.write_string(&sb, ",")
		}
		group := duplicate_groups[gi]
		strings.write_string(&sb, "[")
		for i in 0 ..< len(group) {
			if i > 0 {
				strings.write_string(&sb, ",")
			}
			f := group[i]
			fmt.sbprintf(&sb, `{"path":"%s","size":%d,"mtime":%d}`,
				js_util.json_escape(f.path), f.size, f.mtime)
		}
		strings.write_string(&sb, "]")
	}

	strings.write_string(&sb, `],"related_groups":[`)

	for gi in 0 ..< len(related) {
		if gi > 0 {
			strings.write_string(&sb, ",")
		}
		group := related[gi]
		fmt.sbprintf(&sb, `{"key":"%s","files":[`, js_util.json_escape(group.key))
		for i in 0 ..< len(group.files) {
			if i > 0 {
				strings.write_string(&sb, ",")
			}
			f := group.files[i]
			fmt.sbprintf(&sb, `{"path":"%s","size":%d,"mtime":%d}`,
				js_util.json_escape(f.path), f.size, f.mtime)
		}
		strings.write_string(&sb, "]}")
	}

	strings.write_string(&sb, "]}")
	return strings.to_string(sb)
}

// find_duplicates_to_file writes results to file and returns status JSON.
// Mirrors wayer::storage::find_duplicates_to_file
find_duplicates_to_file :: proc(root_path: string, out_path: string) -> string {
	json := find_duplicates(root_path)
	if !core_heart.write_text_file(out_path, json) {
		return `{"status":"error","reason":"write_failed"}`
	}
	return fmt.tprintf(`{"status":"ok","path":"%s"}`, js_util.json_escape(out_path))
}

// ---------------------------------------------------------------------------
// Walk helpers — context-aware walk to replace lambda captures
// ---------------------------------------------------------------------------

// DupWalkCtx for size-grouping stage
DupWalkCtx :: struct {
	by_size: ^map[u64][dynamic]string,
}

dup_size_cb :: proc(path: string, name: string, size: i64, mtime: i64, ud: rawptr) {
	_ = name
	_ = mtime
	if size <= 0 {
		return
	}
	ctx := cast(^DupWalkCtx)ud
	u := u64(size)
	entry, exists := ctx.by_size^[u]
	if !exists {
		entry = make([dynamic]string, 0, 4, context.temp_allocator)
	}
	append(&entry, strings.clone(path, context.temp_allocator))
	ctx.by_size^[u] = entry
}

// Generic walk with user data — bridges to C fs_walk with context.
WalkWithCtxCb :: proc(path: string, name: string, size: i64, mtime: i64, ud: rawptr)

// walk_ctx_inner is the trampoline for WalkWithCtx
walk_ctx_inner :: proc "c" (path: cstring, name: cstring, size: i64, mtime: i64, ud: rawptr) {
	context = runtime.default_context()
	// ud points to a struct {cb, real_ud}
	Wrapper :: struct {
		cb: WalkWithCtxCb,
		ud: rawptr,
	}
	w := cast(^Wrapper)ud
	// C strings → Odin strings (NUL-terminated, so string(cstring) works)
	p := string(path)
	n := string(name)
	w.cb(p, n, size, mtime, w.ud)
}

walk_files_with_ctx :: proc(root: string, cb: WalkWithCtxCb, ud: rawptr) {
	wrapper := struct {
		cb: WalkWithCtxCb,
		ud: rawptr,
	}{cb, ud}
	c_root := strings.clone_to_cstring(root, context.temp_allocator)
	fs.wayer_fs_walk_files(c_root, walk_ctx_inner, &wrapper)
}
