package search

import "vendor:libc-shim"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:c"

import core_heart "../../../../core/src"
import js_util "../../../../json_utils/src"

WayerWalkEntry :: struct {
	name: cstring,
	path: cstring,
	is_dir: c.int,
	is_file: c.int,
	is_symlink: c.int,
}

WayerWalkResult :: struct {
	entries: [^]WayerWalkEntry,
	count: c.size_t,
	capacity: c.size_t,
}

foreign import libc "system:c"
@(default_calling_convention = "c")
foreign libc {
	wayer_walk_directory :: proc(root: cstring, result: ^WayerWalkResult) -> c.int ---
	wayer_walk_free :: proc(result: ^WayerWalkResult) ---
}


// SearchResult mirrors the C++ SearchResult struct
SearchResult :: struct {
	name: string,
	path: string,
	is_dir: bool,
	match_score: int, // 100 exact, 50 related
}

// search_files performs case-insensitive file-name search
// Mirrors wayer::storage::search_files
search_files :: proc(root_path: string, query: string) -> string {
    q_lower := core_heart.ascii_lower(query)

    if len(q_lower) == 0 {
        return `{"exact_matches":[],"related_matches":[]}`
    }

    root_c := strings.clone_to_cstring(
        root_path,
        context.temp_allocator,
    )

    walk: WayerWalkResult
    if wayer_walk_directory(root_c, &walk) == 0 {
        return `{"error":"directory_walk_failed"}`
    }
    defer wayer_walk_free(&walk)

    exacts: [dynamic]SearchResult
    relateds: [dynamic]SearchResult

    for i in 0 ..< int(walk.count) {
        entry := walk.entries[i]

        // Skip symbolic links and unsupported entry types.
        if entry.is_symlink != 0 {
            continue
        }
        if entry.is_dir == 0 && entry.is_file == 0 {
            continue
        }

        name := string(entry.name)
        path := string(entry.path)
        name_lower := core_heart.ascii_lower(name)

        if name_lower == q_lower {
            append(&exacts, SearchResult{
                name = name,
                path = path,
                is_dir = entry.is_dir != 0,
                match_score = 100,
            }, context.temp_allocator)
        } else if strings.contains(name_lower, q_lower) {
            append(&relateds, SearchResult{
                name = name,
                path = path,
                is_dir = entry.is_dir != 0,
                match_score = 50,
            }, context.temp_allocator)
        }
    }

    sb := strings.builder_make(context.temp_allocator)
    strings.write_string(&sb, `{"exact_matches":[`)

    for i, result in exacts {
        if i > 0 {
            strings.write_string(&sb, ",")
        }

        fmt.sbprintf(
            &sb,
            `{"name":"%s","path":"%s","is_dir":%s}`,
            js_util.json_escape(result.name),
            js_util.json_escape(result.path),
            js_util.bool_to_string(result.is_dir),
        )
    }

    strings.write_string(&sb, `],"related_matches":[`)

    for i, result in relateds {
        if i > 0 {
            strings.write_string(&sb, ",")
        }

        fmt.sbprintf(
            &sb,
            `{"name":"%s","path":"%s","is_dir":%s}`,
            js_util.json_escape(result.name),
            js_util.json_escape(result.path),
            js_util.bool_to_string(result.is_dir),
        )
    }

    strings.write_string(&sb, "]}")
    return strings.to_string(sb)
}

// search_files_to_file writes search results to a file
// Mirrors wayer::storage::search_files_to_file
search_files_to_file :: proc(root_path: string, query: string, out_path: string) -> string {
	json := search_files(root_path, query)
	if !core_heart.write_text_file(out_path, json) {
		return `{"status":"error","reason":"write_failed"}`
	}
	return fmt.tprintf(`{"status":"ok","path":"%s"}`, js_util.json_escape(out_path))
}