package wayer_core

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:strconv"
import "core:strings"

ACTION_PING             :: 1
ACTION_GET_STATUS       :: 2
ACTION_LIST_FILES       :: 3
ACTION_GET_NETWORK_INFO :: 4
ACTION_FILTER_DOCUMENTS :: 5
ACTION_START_LISTENER   :: 6
ACTION_SEARCH_FILES     :: 8
ACTION_FIND_LARGE_FILES :: 9
ACTION_FIND_DUPLICATES  :: 10
ACTION_PLAN_ORGANIZE    :: 11
ACTION_APPLY_ORGANIZE   :: 12
ACTION_GET_CACHED_STATS :: 13
ACTION_INIT_APP_PATHS   :: 14
ACTION_BUILD_INDEX      :: 15
ACTION_INVALIDATE_CACHE :: 16
ACTION_INDEX_META       :: 17
ACTION_SEARCH_INDEX     :: 18
ACTION_READ_TEXT_FILE   :: 19

BAD_PAYLOAD :: `{"status":"error","reason":"bad_payload"}`

foreign import shim "system:wayer_shim"

@(default_calling_convention = "c")
foreign shim {
	wayer_list_files              :: proc(path: cstring) -> cstring ---
	wayer_get_network_info        :: proc() -> cstring ---
	wayer_filter_documents        :: proc(payload: cstring) -> cstring ---
	wayer_start_listener          :: proc(port: c.int) -> cstring ---
	wayer_search_files_to_file    :: proc(root, query, out_path: cstring) -> cstring ---
	wayer_find_large_files_to_file :: proc(root: cstring, min_bytes: u64, max_results: c.int, out_path: cstring) -> cstring ---
	wayer_find_duplicates_to_file :: proc(root, out_path: cstring) -> cstring ---
	wayer_plan_organize_to_file   :: proc(root, out_path: cstring) -> cstring ---
	wayer_apply_organize_file     :: proc(plan_path, report_path: cstring) -> cstring ---
	wayer_read_cache_if_fresh     :: proc(cache_path: cstring, max_age: c.int) -> cstring ---
	wayer_write_storage_stats     :: proc(root, cache_path: cstring, known_bytes: u64) -> cstring ---
	wayer_build_index             :: proc(root: cstring) -> cstring ---
	wayer_index_meta              :: proc() -> cstring ---
	wayer_search_index_to_file    :: proc(query: cstring, max_results: u64, out_path: cstring) -> cstring ---
	wayer_read_text_file          :: proc(path: cstring, max_bytes: u64) -> cstring ---
	wayer_invalidate_cache        :: proc(payload: cstring) -> c.bool ---
	wayer_init_app_paths          :: proc(app_root: cstring) -> cstring --- // returns final JSON reply
	wayer_json_escape             :: proc(s: cstring) -> cstring ---
	wayer_log_info                :: proc(tag, msg: cstring) ---
	wayer_log_error               :: proc(tag, msg: cstring) ---
}

// Per-thread so concurrent JNI calls don't stomp each other.
@(thread_local) reply_buffer: [16384]u8

reply :: proc(s: string) -> cstring {
	n := min(len(s), len(reply_buffer) - 1)
	copy(reply_buffer[:n], s[:n])
	reply_buffer[n] = 0
	return cstring(&reply_buffer[0])
}

reply_c :: proc(s: cstring) -> cstring {
	return reply(string(s)) // string(nil cstring) is ""
}

// Substrings of payload are NOT NUL-terminated, so clone before passing to C.
cs :: proc(s: string) -> cstring {
	return strings.clone_to_cstring(s, context.temp_allocator)
}

all_digits :: proc(s: string) -> bool {
	for ch in s {
		if ch < '0' || ch > '9' { return false }
	}
	return len(s) > 0
}

split_payload :: proc(payload: string) -> []string {
	parts, _ := strings.split(payload, "|", context.temp_allocator)
	return parts
}

split_trailing_number :: proc(payload: string, default_value: u64) -> (text: string, number: u64) {
	text, number = payload, default_value
	pos := strings.last_index_byte(payload, '|')
	if pos <= 0 { return }
	tail := payload[pos + 1:]
	if !all_digits(tail) { return }
	if n, ok := strconv.parse_u64(tail, 10); ok {
		return payload[:pos], n
	}
	return
}

init_app_paths :: proc(raw: string) -> cstring {
	root := strings.trim_right(raw, "\n\r \t/")
	if len(root) == 0 { return reply(`{"error":"bad_payload"}`) }
	if !strings.has_suffix(root, "/wayer") {
		root = strings.concatenate({root, "/wayer"}, context.temp_allocator)
	}
	return reply_c(wayer_init_app_paths(cs(root)))
}

route_action :: proc(action_id: int, payload: string) -> cstring {
	switch action_id {
	case ACTION_PING:
		return reply(fmt.tprintf("PONG: %s", payload))
	case ACTION_GET_STATUS:
		return reply(`{"status": "ready", "engine": "Odin"}`)
	case ACTION_LIST_FILES:
		return reply_c(wayer_list_files(cs(payload)))
	case ACTION_GET_NETWORK_INFO:
		return reply_c(wayer_get_network_info())
	case ACTION_FILTER_DOCUMENTS:
		return reply_c(wayer_filter_documents(cs(payload)))
	case ACTION_START_LISTENER:
		return reply_c(wayer_start_listener(8080))

	case ACTION_SEARCH_FILES:
		parts := split_payload(payload)
		if len(parts) < 3 || len(parts[1]) == 0 { return reply(BAD_PAYLOAD) }
		query := strings.join(parts[2:], "|", context.temp_allocator)
		return reply_c(wayer_search_files_to_file(cs(parts[0]), cs(query), cs(parts[1])))

	case ACTION_FIND_LARGE_FILES:
		parts := split_payload(payload)
		if len(parts) < 4 || len(parts[3]) == 0 { return reply(BAD_PAYLOAD) }
		root := parts[0] if len(parts[0]) > 0 else "/storage/emulated/0"
		min_bytes := u64(10 * 1024 * 1024)
		max_results := 50
		if v, ok := strconv.parse_u64(parts[1], 10); ok { min_bytes = v }
		if v, ok := strconv.parse_int(parts[2], 10); ok { max_results = v }
		return reply_c(wayer_find_large_files_to_file(cs(root), min_bytes, c.int(max_results), cs(parts[3])))

	case ACTION_FIND_DUPLICATES:
		parts := split_payload(payload)
		if len(parts) < 2 || len(parts[1]) == 0 { return reply(BAD_PAYLOAD) }
		return reply_c(wayer_find_duplicates_to_file(cs(parts[0]), cs(parts[1])))

	case ACTION_PLAN_ORGANIZE:
		parts := split_payload(payload)
		if len(parts) < 2 || len(parts[1]) == 0 { return reply(BAD_PAYLOAD) }
		return reply_c(wayer_plan_organize_to_file(cs(parts[0]), cs(parts[1])))

	case ACTION_APPLY_ORGANIZE:
		parts := split_payload(payload)
		if len(parts) < 2 || len(parts[0]) == 0 || len(parts[1]) == 0 { return reply(BAD_PAYLOAD) }
		return reply_c(wayer_apply_organize_file(cs(parts[0]), cs(parts[1])))

	case ACTION_GET_CACHED_STATS:
		
		parts := split_payload(payload)
		if len(parts) < 3 { return reply(BAD_PAYLOAD) }
		
		max_age, _ := strconv.parse_int(parts[2], 10)

		//check if the cache is fresh one 
		cached := wayer_read_cache_if_fresh(cs(parts[0]), c.int(max_age))
		if len(cached) > 0 {
			return reply(fmt.tprintf(`{"status":"ok","path":"%s"}`, wayer_json_escape(cs(parts[0]))))
		}
		known_bytes := u64(0)
		if len(parts) > 3 {
			if v, ok := strconv.parse_u64(parts[3], 10); ok { known_bytes = v }
		}
		return reply_c(wayer_write_storage_stats(cs(parts[1]), cs(parts[0]), known_bytes))

	case ACTION_INIT_APP_PATHS:
		return init_app_paths(payload)
	case ACTION_BUILD_INDEX:
		return reply_c(wayer_build_index(cs(payload)))
	case ACTION_INDEX_META:
		return reply_c(wayer_index_meta())

	case ACTION_SEARCH_INDEX:
		parts := split_payload(payload)
		if len(parts) == 0 || len(parts[0]) == 0 { return reply(BAD_PAYLOAD) }
		max_results := u64(50)
		query_from := 1
		if len(parts) > 1 && all_digits(parts[1]) {
			if v, ok := strconv.parse_u64(parts[1], 10); ok {
				max_results = v
				query_from = 2
			}
		}
		query := ""
		if query_from < len(parts) {
			query = strings.join(parts[query_from:], "|", context.temp_allocator)
		}
		return reply_c(wayer_search_index_to_file(cs(query), max_results, cs(parts[0])))

	case ACTION_READ_TEXT_FILE:
		path, max_bytes := split_trailing_number(payload, 0)
		return reply_c(wayer_read_text_file(cs(path), max_bytes))

	case ACTION_INVALIDATE_CACHE:
		if wayer_invalidate_cache(cs(payload)) {
			return reply(`{"status":"invalidated"}`)
		}
		return reply(`{"status":"missing"}`)
	}

	wayer_log_error("WayerEngine", "unknown action from Java")
	return reply(`{"error": "unknown_action"}`)
}

@(export)
wayer_init_engine :: proc "c" () {
	context = runtime.default_context()
	wayer_log_info("WayerEngine", "Odin engine initialized")
}

@(export)
wayer_route_action :: proc "c" (action_id: c.int, payload: cstring) -> cstring {
	context = runtime.default_context() // `proc "c"` has no context; Odin code needs one
	defer free_all(context.temp_allocator)
	return route_action(int(action_id), string(payload))
}