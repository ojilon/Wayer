package storage

import "core:c"
import "core:fmt"
import "core:strings"

import core_heart "../../core/src"

// C ABI functions (defined in index_c.c, declared in wayer_core.odin)
@(default_calling_convention = "c")
foreign {
	wayer_build_index         :: proc(root, index_path: cstring) -> cstring ---
	wayer_index_meta          :: proc(index_path: cstring) -> cstring ---
	wayer_search_index_to_file :: proc(query: cstring, max_results: u64, out_path, index_path: cstring) -> cstring ---
	wayer_group_index_by_day   :: proc(index_path, out_path: cstring, max_days, max_per_day: c.int) -> cstring ---
}

cs :: proc(s: string) -> cstring {
	return strings.clone_to_cstring(s, context.temp_allocator)
}

reply :: proc(s: string) -> string {
	return s
}

// Build index from root directory
build_index :: proc(root: string, index_path: string) -> string {
	if len(root) == 0 || len(index_path) == 0 {
		return `{"error":"bad_payload"}`
	}
	return reply(string(wayer_build_index(cs(root), cs(index_path))))
}

// Get index metadata
index_meta :: proc(index_path: string) -> string {
	if len(index_path) == 0 {
		return `{"error":"bad_payload"}`
	}
	return reply(string(wayer_index_meta(cs(index_path))))
}

// Search index and write results to file
search_index_to_file :: proc(query: string, max_results: u64, out_path: string, index_path: string) -> string {
	if len(out_path) == 0 || len(index_path) == 0 {
		return `{"error":"bad_payload"}`
	}
	if max_results == 0 {
		max_results = 50
	}
	if max_results > 200 {
		max_results = 200
	}
	return reply(string(wayer_search_index_to_file(cs(query), max_results, cs(out_path), cs(index_path))))
}

// Group index entries by day
group_index_by_day :: proc(index_path: string, out_path: string, max_days: int, max_per_day: int) -> string {
	if len(index_path) == 0 || len(out_path) == 0 {
		return `{"error":"bad_payload"}`
	}
	if max_days <= 0 {
		max_days = 14
	}
	if max_days > 32 {
		max_days = 32
	}
	if max_per_day <= 0 {
		max_per_day = 50
	}
	if max_per_day > 64 {
		max_per_day = 64
	}
	return reply(string(wayer_group_index_by_day(cs(index_path), cs(out_path), c.int(max_days), c.int(max_per_day))))
}