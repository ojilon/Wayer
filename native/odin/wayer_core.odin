// =============================================================================
// wayer_core.odin — Odin entry package
//
// This is the package that CMake asks Odin to build (native/odin/).
// It owns:
//   - the action-id router (wayer_route_action)
//   - the exported C ABI that jni/wayer_engine.c calls
//
// Other Odin packages (storage, core_heart, documents, transfer, preview, media)
// live next to their C++ twins under native/<module>/src/*.odin and are imported
// relatively. Drop a new .odin file anywhere under native/, import it from here
// (or from an already-imported package), and CMake will pick it up automatically.
// =============================================================================

package wayer_core

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:strconv"
import "core:strings"

import core_heart "../core/src"
import storage "../storage/src"
import documents "../documents/src"
import transfer "../transfer/src"
import preview "../preview/src"
import media "../media/src"

// Action IDs — must stay identical to NativeEngine.java
ACTION_PING             :: 1
ACTION_GET_STATUS       :: 2
ACTION_LIST_FILES       :: 3
ACTION_GET_NETWORK_INFO :: 4
ACTION_FILTER_DOCUMENTS :: 5
ACTION_START_LISTENER   :: 6
// 7 was the old direct GET_STORAGE_STATS; now unused (see GET_CACHED_STATS)
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
ACTION_GROUP_INDEX_BY_DAY :: 21

BAD_PAYLOAD :: `{"status":"error","reason":"bad_payload"}`

// Index lives in the same .so (wayer_storage / index_c.c)
foreign {
	wayer_build_index :: proc(root, index_path: cstring) -> cstring ---
	wayer_index_meta :: proc(index_path: cstring) -> cstring ---
	wayer_search_index_to_file :: proc(query: cstring, max_results: u64, out_path, index_path: cstring) -> cstring ---
	wayer_group_index_by_day :: proc(index_path, out_path: cstring, max_days, max_per_day: c.int) -> cstring ---
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
	// Call core_heart's ensure_app_dirs and write_paths_manifest
	report := core_heart.ensure_app_dirs(root)
	core_heart.set_app_paths(report.paths)
	manifest := core_heart.write_paths_manifest(report)
	
	// Build JSON reply matching C++ format
	json := fmt.tprintf(`{"status":"paths_set","manifest":"%s","all_ready":%s,"root":"%s","cache":"%s","temp":"%s","logs":"%s"}`,
		core_heart.json_escape(manifest),
		core_heart.bool_to_string(report.all_ready()),
		core_heart.json_escape(report.paths.root),
		core_heart.json_escape(report.paths.cache),
		core_heart.json_escape(report.paths.temp),
		core_heart.json_escape(report.paths.logs))
	return reply(json)
}

route_action :: proc(action_id: int, payload: string) -> cstring {
	switch action_id {
	case ACTION_PING:
		return reply(fmt.tprintf("PONG: %s", payload))
	case ACTION_GET_STATUS:
		return reply(`{"status": "ready", "engine": "Odin"}`)
	case ACTION_LIST_FILES:
		return reply(storage.list_files(payload))
	case ACTION_GET_NETWORK_INFO:
		return reply(transfer.get_network_info())
	case ACTION_FILTER_DOCUMENTS:
		return reply(documents.filter_documents(payload))
	case ACTION_START_LISTENER:
		return reply(transfer.start_listener(8080))

	case ACTION_SEARCH_FILES:
		parts := split_payload(payload)
		if len(parts) < 3 || len(parts[1]) == 0 { return reply(BAD_PAYLOAD) }
		query := strings.join(parts[2:], "|", context.temp_allocator)
		return reply(storage.search_files_to_file(parts[0], query, parts[1]))

	case ACTION_FIND_LARGE_FILES:
		parts := split_payload(payload)
		if len(parts) < 4 || len(parts[3]) == 0 { return reply(BAD_PAYLOAD) }
		root := parts[0]
		if len(root) == 0 { root = "/storage/emulated/0" }
		min_bytes := u64(10 * 1024 * 1024)
		max_results := 50
		if v, ok := strconv.parse_u64(parts[1], 10); ok { min_bytes = v }
		if v, ok := strconv.parse_int(parts[2], 10); ok { max_results = v }
		return reply(storage.find_large_files_to_file(root, min_bytes, max_results, parts[3]))

	case ACTION_FIND_DUPLICATES:
		parts := split_payload(payload)
		if len(parts) < 2 || len(parts[1]) == 0 { return reply(BAD_PAYLOAD) }
		return reply(storage.find_duplicates_to_file(parts[0], parts[1]))

	case ACTION_PLAN_ORGANIZE:
		parts := split_payload(payload)
		if len(parts) < 2 || len(parts[1]) == 0 { return reply(BAD_PAYLOAD) }
		return reply(storage.plan_organize_to_file(parts[0], parts[1]))

	case ACTION_APPLY_ORGANIZE:
		parts := split_payload(payload)
		if len(parts) < 2 || len(parts[0]) == 0 || len(parts[1]) == 0 { return reply(BAD_PAYLOAD) }
		return reply(storage.apply_organize_file(parts[0], parts[1]))

	case ACTION_GET_CACHED_STATS:
		parts := split_payload(payload)
		if len(parts) < 3 { return reply(BAD_PAYLOAD) }
		
		max_age, _ := strconv.parse_int(parts[2], 10)

		// Check if the cache is fresh
		cached := storage.read_cache_if_fresh(parts[0], max_age)
		if len(cached) > 0 {
			return reply(fmt.tprintf(`{"status":"ok","path":"%s"}`, core_heart.json_escape(parts[0])))
		}
		known_bytes := u64(0)
		if len(parts) > 3 {
			if v, ok := strconv.parse_u64(parts[3], 10); ok { known_bytes = v }
		}
		return reply(storage.write_storage_stats(parts[1], parts[0], known_bytes))

	case ACTION_INIT_APP_PATHS:
		return init_app_paths(payload)
	case ACTION_BUILD_INDEX:
		// payload: root|index_path
		parts := split_payload(payload)
		if len(parts) < 2 || len(parts[0]) == 0 || len(parts[1]) == 0 {
			return reply(BAD_PAYLOAD)
		}
		return reply_c(wayer_build_index(cs(parts[0]), cs(parts[1])))
	case ACTION_INDEX_META:
		// payload: index_path
		if len(payload) == 0 { return reply(BAD_PAYLOAD) }
		return reply_c(wayer_index_meta(cs(payload)))

	case ACTION_SEARCH_INDEX:
		// payload: out_path|index_path|max_results|query
		parts := split_payload(payload)
		if len(parts) < 2 || len(parts[0]) == 0 || len(parts[1]) == 0 {
			return reply(BAD_PAYLOAD)
		}
		max_results := u64(50)
		query_from := 2
		if len(parts) > 2 && all_digits(parts[2]) {
			if v, ok := strconv.parse_u64(parts[2], 10); ok {
				max_results = v
				query_from = 3
			}
		}
		query := ""
		if query_from < len(parts) {
			query = strings.join(parts[query_from:], "|", context.temp_allocator)
		}
		return reply_c(wayer_search_index_to_file(cs(query), max_results, cs(parts[0]), cs(parts[1])))

	case ACTION_READ_TEXT_FILE:
		path, max_bytes := split_trailing_number(payload, 0)
		return reply(preview.read_text_file(path, max_bytes))

	case ACTION_INVALIDATE_CACHE:
		if storage.invalidate_cache(payload) {
			return reply(`{"status":"invalidated"}`)
		}
		return reply(`{"status":"missing"}`)

	case ACTION_GROUP_INDEX_BY_DAY:
		// payload: out_path|index_path|max_days|max_per_day
		parts := split_payload(payload)
		if len(parts) < 2 || len(parts[0]) == 0 || len(parts[1]) == 0 {
			return reply(BAD_PAYLOAD)
		}
		max_days := 14
		max_per_day := 50
		if len(parts) > 2 {
			if v, ok := strconv.parse_int(parts[2], 10); ok { max_days = v }
		}
		if len(parts) > 3 {
			if v, ok := strconv.parse_int(parts[3], 10); ok { max_per_day = v }
		}
		return reply_c(wayer_group_index_by_day(cs(parts[1]), cs(parts[0]), c.int(max_days), c.int(max_per_day)))
	}

	core_heart.error("WayerEngine", "unknown action from Java")
	return reply(`{"error": "unknown_action"}`)
}

@(export)
wayer_init_engine :: proc "c" () {
	context = runtime.default_context()
	core_heart.info("WayerEngine", "Odin engine initialized")
}

@(export)
wayer_route_action :: proc "c" (action_id: c.int, payload: cstring) -> cstring {
	context = runtime.default_context() // `proc "c"` has no context; Odin code needs one
	defer free_all(context.temp_allocator)
	return route_action(int(action_id), string(payload))
}

// C ABI exports for functions that are implemented in Odin (not in C shim)
// These replace the wayer_shim.cpp C++ shim
@(export)
wayer_list_files :: proc "c" (path: cstring) -> cstring {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	return cs(storage.list_files(string(path)))
}

@(export)
wayer_get_network_info :: proc "c" () -> cstring {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	return cs(transfer.get_network_info())
}

@(export)
wayer_filter_documents :: proc "c" (payload: cstring) -> cstring {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	return cs(documents.filter_documents(string(payload)))
}

@(export)
wayer_start_listener :: proc "c" (port: c.int) -> cstring {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	return cs(transfer.start_listener(int(port)))
}

@(export)
wayer_search_files_to_file :: proc "c" (root, query, out_path: cstring) -> cstring {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	return cs(storage.search_files_to_file(string(root), string(query), string(out_path)))
}

@(export)
wayer_find_large_files_to_file :: proc "c" (root: cstring, min_bytes: u64, max_results: c.int, out_path: cstring) -> cstring {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	return cs(storage.find_large_files_to_file(string(root), min_bytes, int(max_results), string(out_path)))
}

@(export)
wayer_find_duplicates_to_file :: proc "c" (root, out_path: cstring) -> cstring {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	return cs(storage.find_duplicates_to_file(string(root), string(out_path)))
}

@(export)
wayer_plan_organize_to_file :: proc "c" (root, out_path: cstring) -> cstring {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	return cs(storage.plan_organize_to_file(string(root), string(out_path)))
}

@(export)
wayer_apply_organize_file :: proc "c" (plan_path, report_path: cstring) -> cstring {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	return cs(storage.apply_organize_file(string(plan_path), string(report_path)))
}

@(export)
wayer_read_cache_if_fresh :: proc "c" (cache_path: cstring, max_age: c.int) -> cstring {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	return cs(storage.read_cache_if_fresh(string(cache_path), int(max_age)))
}

@(export)
wayer_read_text_file :: proc "c" (path: cstring, max_bytes: u64) -> cstring {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	return cs(preview.read_text_file(string(path), max_bytes))
}

@(export)
wayer_invalidate_cache :: proc "c" (cache_path: cstring) -> c.bool {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	return storage.invalidate_cache(string(cache_path))
}

@(export)
wayer_init_app_paths :: proc "c" (app_root: cstring) -> cstring {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	return cs(init_app_paths(string(app_root)))
}

@(export)
wayer_json_escape :: proc "c" (s: cstring) -> cstring {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	return cs(core_heart.json_escape(string(s)))
}

@(export)
wayer_log_info :: proc "c" (tag, msg: cstring) {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	core_heart.info(string(tag), string(msg))
}

@(export)
wayer_log_error :: proc "c" (tag, msg: cstring) {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	core_heart.error(string(tag), string(msg))
}