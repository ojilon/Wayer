// =============================================================================
// search.odin — case-insensitive file-name search (live, scoped)
//
// Part of package storage. Implements the live search used by the Files tab's
// search bar (not the Transfer index search — that uses SEARCH_INDEX via
// index_c.c). This search walks the requested `root` on demand and matches
// file/dir names against `query` (case-insensitive, ASCII lowercasing).
//
// Results are split
//   exact_matches   — name equals query (score 100)
//   related_matches — name contains query as substring (score 50)
//
// Output shapes
//   Success: {"exact_matches":[{"name","path","is_dir":bool},...],
//             "related_matches":[...]}
//   Error:   {"error":"directory_walk_failed"}
//
// File-backed variant
//   search_files_to_file writes the same JSON to `out_path` and returns
//   {"status":"ok","path":...} so Java reads from the file instead of JNI.
//
// Android 10 / bionic
//   Walk uses wayer_walk_directory from collect_data.c (opendir/readdir/stat
//   only — no statx). The C result (WayerWalkResult) is a flat array of
//   entries allocated in C; we free it with wayer_walk_free after use.
//
// Mirrors: wayer::storage::search_files, search_files_to_file
//          in native/storage/modules/search/src/file_search.cpp
//          and native/storage/src/search.cpp
// =============================================================================

package storage

import "core:fmt"
import "core:strings"
import "core:c"

import core_heart "../../core/src"
import js_util "../../json_utils/src"

// ---------------------------------------------------------------------------
// C walk types — from collect_data.c / dir_walk_android.c
// ---------------------------------------------------------------------------

WayerWalkEntry :: struct {
	name:       cstring,
	path:       cstring,
	is_dir:     c.int,
	is_file:    c.int,
	is_symlink: c.int,
}

WayerWalkResult :: struct {
	entries:  [^]WayerWalkEntry,
	count:    c.size_t,
	capacity: c.size_t,
}

foreign import walk_lib "system:c"

@(default_calling_convention = "c")
foreign walk_lib {
	wayer_walk_directory :: proc(root: cstring, result: ^WayerWalkResult) -> c.int ---
	wayer_walk_free      :: proc(result: ^WayerWalkResult) ---
}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

// SearchResult mirrors the C++ struct used before file-backed search.
SearchResult :: struct {
	name:        string,
	path:        string,
	is_dir:      bool,
	match_score: int, // 100 exact, 50 related
}

// ---------------------------------------------------------------------------
// search_files — core logic
// ---------------------------------------------------------------------------

// search_files performs case-insensitive file-name search under root_path.
// Mirrors wayer::storage::search_files
search_files :: proc(root_path: string, query: string) -> string {
	q_lower := core_heart.ascii_lower(query)

	if len(q_lower) == 0 {
		return `{"exact_matches":[],"related_matches":[]}`
	}

	root_c := strings.clone_to_cstring(root_path, context.temp_allocator)

	walk: WayerWalkResult
	// wayer_walk_directory returns 0 on failure, non-zero on success
	if wayer_walk_directory(root_c, &walk) == 0 {
		return `{"error":"directory_walk_failed"}`
	}
	defer wayer_walk_free(&walk)

	exacts   := make([dynamic]SearchResult, context.temp_allocator)
	relateds := make([dynamic]SearchResult, context.temp_allocator)

	for i in 0 ..< int(walk.count) {
		entry := walk.entries[i]

		// Skip symbolic links (avoid loops) and non-file/dir entries.
		if entry.is_symlink != 0 {
			continue
		}
		if entry.is_dir == 0 && entry.is_file == 0 {
			continue
		}

		// Entry names/paths are cstrings from C — copy to Odin strings.
		name := string(entry.name)
		path := string(entry.path)
		name_lower := core_heart.ascii_lower(name)

		if name_lower == q_lower {
			append(&exacts, SearchResult{
				name = strings.clone(name, context.temp_allocator),
				path = strings.clone(path, context.temp_allocator),
				is_dir = entry.is_dir != 0,
				match_score = 100,
			})
		} else if strings.contains(name_lower, q_lower) {
			append(&relateds, SearchResult{
				name = strings.clone(name, context.temp_allocator),
				path = strings.clone(path, context.temp_allocator),
				is_dir = entry.is_dir != 0,
				match_score = 50,
			})
		}
	}

	// Build JSON response
	sb := strings.builder_make(context.temp_allocator)
	strings.write_string(&sb, `{"exact_matches":[`)

	for i in 0 ..< len(exacts) {
		if i > 0 {
			strings.write_string(&sb, ",")
		}
		r := exacts[i]
		fmt.sbprintf(&sb, `{"name":"%s","path":"%s","is_dir":%s}`,
			js_util.json_escape(r.name),
			js_util.json_escape(r.path),
			js_util.bool_to_string(r.is_dir),
		)
	}

	strings.write_string(&sb, `],"related_matches":[`)

	for i in 0 ..< len(relateds) {
		if i > 0 {
			strings.write_string(&sb, ",")
		}
		r := relateds[i]
		fmt.sbprintf(&sb, `{"name":"%s","path":"%s","is_dir":%s}`,
			js_util.json_escape(r.name),
			js_util.json_escape(r.path),
			js_util.bool_to_string(r.is_dir),
		)
	}

	strings.write_string(&sb, "]}")
	return strings.to_string(sb)
}

// search_files_to_file writes search results to out_path and returns status JSON.
// Mirrors wayer::storage::search_files_to_file
search_files_to_file :: proc(root_path: string, query: string, out_path: string) -> string {
	json := search_files(root_path, query)
	if !core_heart.write_text_file(out_path, json) {
		return `{"status":"error","reason":"write_failed"}`
	}
	return fmt.tprintf(`{"status":"ok","path":"%s"}`, js_util.json_escape(out_path))
}
