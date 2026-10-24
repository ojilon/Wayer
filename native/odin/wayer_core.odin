// =============================================================================
// wayer_core.odin — Odin entry package (the only package CMake builds)
//
// This is the package that `native/CMakeLists.txt` asks the Odin compiler to
// build into libwayer_core_odin.a. It owns:
//
//   1. The action-id router (wayer_route_action) — Java's NativeEngine.java
//      calls processAction(actionId, payload) → JNI → wayer_route_action.
//   2. The exported C ABI that jni/wayer_engine.c links (wayer_list_files,
//      wayer_get_network_info, etc.) — these replace the old wayer_shim.cpp
//      once the Odin side is considered canonical.
//
// Other Odin packages live next to their C++ twins under native/<module>/src/*.odin:
//
//   native/core/src/*.odin      → package core_heart
//   native/storage/src/*.odin   → package storage
//   native/documents/src/*.odin → package documents
//   native/transfer/src/*.odin  → package transfer
//   native/preview/src/*.odin   → package preview
//   native/media/src/*.odin     → package media
//
// To add a new .odin file, drop it anywhere under native/ and import it from
// an already-imported package (e.g. wayer_core.odin or storage.odin).
// CMake's GLOB_RECURSE with CONFIGURE_DEPENDS picks it up automatically.
//
// Odin October 2025 + Android 10 notes
//   * Target: linux_arm64 + -subtarget:android (see native/CMakeLists.txt)
//   * ODIN_OS check uses enum `.Android` not string "android"
//   * core:os file ops are NOT used for filesystem — all I/O via C wrappers
//     in android_fs.c (opendir/readdir/stat only; no statx → bionic-safe on
//     API 29 seccomp). See native/core/src/android_fs.c header for the
//     complete bionic allowlist.
//   * Thread-local storage: Bridge.java serializes all native file jobs on a
//     single-thread executor, so a process-wide reply buffer is safe. We keep
//     a single `reply_buffer` and protect it via executor serialization (not
//     per-thread). This avoids needing `thread_local` attribute which has
//     subtle linker requirements on Android's Bionic libc.
// =============================================================================

package wayer_core

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:strconv"
import "core:strings"

import core_heart "../core/src"
import storage    "../storage/src"
import documents  "../documents/src"
import transfer   "../transfer/src"
import preview    "../preview/src"
import media      "../media/src"
import js_util "../json_utils/src"

// ---------------------------------------------------------------------------
// Action IDs — must stay identical to NativeEngine.java's constants
// ---------------------------------------------------------------------------
ACTION_PING               :: 1
ACTION_GET_STATUS         :: 2
ACTION_LIST_FILES         :: 3
ACTION_GET_NETWORK_INFO   :: 4
ACTION_FILTER_DOCUMENTS   :: 5
ACTION_START_LISTENER     :: 6
// 7 was the old direct GET_STORAGE_STATS; now unused (merged into 13)
ACTION_SEARCH_FILES       :: 8
ACTION_FIND_LARGE_FILES   :: 9
ACTION_FIND_DUPLICATES    :: 10
ACTION_PLAN_ORGANIZE      :: 11
ACTION_APPLY_ORGANIZE     :: 12
ACTION_GET_CACHED_STATS   :: 13
ACTION_INIT_APP_PATHS     :: 14
ACTION_BUILD_INDEX        :: 15
ACTION_INVALIDATE_CACHE   :: 16
ACTION_INDEX_META         :: 17
ACTION_SEARCH_INDEX       :: 18
ACTION_READ_TEXT_FILE     :: 19
ACTION_GROUP_INDEX_BY_DAY :: 21

BAD_PAYLOAD :: `{"status":"error","reason":"bad_payload"}`

// ---------------------------------------------------------------------------
// C ABI — index & group-by-day live in wayer_storage (index_c.c)
// They are heap-heavy and streaming; Odin just forwards via FFI.
// ---------------------------------------------------------------------------
foreign import index_c "system:c"

@(default_calling_convention = "c")
foreign index_c {
	wayer_build_index          :: proc(root, index_path: cstring) -> cstring ---
	wayer_index_meta           :: proc(index_path: cstring) -> cstring ---
	wayer_search_index_to_file :: proc(query: cstring, max_results: u64, out_path, index_path: cstring) -> cstring ---
	wayer_group_index_by_day   :: proc(index_path, out_path: cstring, max_days, max_per_day: c.int) -> cstring ---
}

// ---------------------------------------------------------------------------
// Reply buffer — JNI-compatible, bionic-safe
// ---------------------------------------------------------------------------
// Bridge.java guarantees only one native file job at a time (single-thread
// executor), so a single process-wide buffer is safe. No thread_local needed;
// avoids Bionic TLS quirks on Android 10 where TLS via __tls_get_addr may
// fail if the library is loaded without RTLD_GLOBAL.
// Size 16 KiB fits every small reply (the large payloads are file-backed).
reply_buffer: [16384]u8

// reply copies `s` into the reply buffer and returns a cstring.
// The buffer is valid until the next reply() on the same thread (which with
// Bridge's serialization means until the next JNI call completes).
reply :: proc(s: string) -> cstring {
	n := min(len(s), len(reply_buffer) - 1)
	copy(reply_buffer[:n], s)
	reply_buffer[n] = 0
	return cstring(&reply_buffer[0])
}

// reply_c wraps a C string reply (handles nil → "").
reply_c :: proc(s: cstring) -> cstring {
	if s == nil {
		return reply("")
	}
	return reply(string(s))
}

// cs clones an Odin string to NUL-terminated cstring on temp_allocator.
// Needed because payload substrings from split() are not NUL-terminated.
cs :: proc(s: string) -> cstring {
	return strings.clone_to_cstring(s, context.temp_allocator)
}

// ---------------------------------------------------------------------------
// Payload helpers — pipe-delimited format used by NativeEngine.java
// ---------------------------------------------------------------------------

all_digits :: proc(s: string) -> bool {
	if len(s) == 0 do return false
	for ch in s {
		if ch < '0' || ch > '9' { return false }
	}
	return true
}

split_payload :: proc(payload: string) -> []string {
	parts, _ := strings.split(payload, "|", context.temp_allocator)
	return parts
}

// split_trailing_number splits "text|123" into (text, 123).
// Used by READ_TEXT_FILE where payload is "path|max_bytes".
split_trailing_number :: proc(payload: string, default_value: u64) -> (text: string, number: u64) {
	text, number = payload, default_value
	pos := strings.last_index_byte(payload, '|')
	if pos <= 0 do return
	tail := payload[pos + 1:]
	if !all_digits(tail) do return
	if n, ok := strconv.parse_u64(tail, 10); ok {
		return payload[:pos], n
	}
	return
}

// ---------------------------------------------------------------------------
// INIT_APP_PATHS — Java passes filesDir once, we create layout + manifest
// ---------------------------------------------------------------------------

init_app_paths :: proc(raw: string) -> cstring {
	// Trim trailing slashes/whitespace so "/data/.../files/" and "/data/.../files" match
	root := strings.trim_right(raw, "\n\r \t/")
	if len(root) == 0 {
		return reply(`{"error":"bad_payload"}`)
	}
	// Ensure canonical <root>/wayer suffix so the private subdir is consistent
	// with AppDirs.privateRoot() on the Java side.
	if !strings.has_suffix(root, "/wayer") {
		root = strings.concatenate({root, "/wayer"}, context.temp_allocator)
	}

	report   := core_heart.ensure_app_dirs(root)
	core_heart.set_app_paths(report.paths)
	manifest := core_heart.write_paths_manifest(report)

	// Reply shape must match C++ wayer_init_app_paths (PathRegistry parses it)
	json := fmt.tprintf(
		`{"status":"paths_set","manifest":"%s","all_ready":%s,"root":"%s","cache":"%s","temp":"%s","logs":"%s"}`,
		js_util.json_escape(manifest),
		js_util.bool_to_string(all_ready(report)),
		js_util.json_escape(report.paths.root),
		js_util.json_escape(report.paths.cache),
		js_util.json_escape(report.paths.temp),
		js_util.json_escape(report.paths.logs),
	)
	return reply(json)
}

// all_ready helper — mirrors AppDirsReport::all_ready() in Odin (for JSON)
all_ready :: proc(report: core_heart.AppDirsReport) -> bool {
	return report.root.ready && report.cache.ready && report.temp.ready && report.logs.ready
}

// ---------------------------------------------------------------------------
// Router — mirrors jni/wayer_engine.c → processAction(actionId, payload)
// ---------------------------------------------------------------------------

route_action :: proc(action_id: int, payload: string) -> cstring {
	switch action_id {
	case ACTION_PING:
		return reply(fmt.tprintf("PONG: %s", payload))

	case ACTION_GET_STATUS:
		return reply(`{"status":"ready","engine":"Odin"}`)

	case ACTION_LIST_FILES:
		return reply(storage.list_files(payload))

	case ACTION_GET_NETWORK_INFO:
		return reply(transfer.get_network_info())

	case ACTION_FILTER_DOCUMENTS:
		return reply(documents.filter_documents(payload))

	case ACTION_START_LISTENER:
		// Legacy: Java's TransferFragment now passes port in payload, but older
		// call sites with no payload used 8080. Keep compat.
		port := 8080
		if v, ok := strconv.parse_int(strings.trim_space(payload), 10); ok && v > 0 && v < 65536 {
			port = v
		}
		return reply(transfer.start_listener(port))

	case ACTION_SEARCH_FILES:
		// payload: root|out_path|query (query may contain "|")
		parts := split_payload(payload)
		if len(parts) < 3 || len(parts[1]) == 0 do return reply(BAD_PAYLOAD)
		query := strings.join(parts[2:], "|", context.temp_allocator)
		return reply(storage.search_files_to_file(parts[0], query, parts[1]))

	case ACTION_FIND_LARGE_FILES:
		// payload: root|min_bytes|max_results|out_path
		parts := split_payload(payload)
		if len(parts) < 4 || len(parts[3]) == 0 do return reply(BAD_PAYLOAD)
		root := parts[0]
		if len(root) == 0 do root = "/storage/emulated/0"
		min_bytes   := u64(10 * 1024 * 1024)
		max_results := 50
		if v, ok := strconv.parse_u64(parts[1], 10); ok { min_bytes = v }
		if v, ok := strconv.parse_int(parts[2], 10); ok { max_results = v }
		return reply(storage.find_large_files_to_file(root, min_bytes, max_results, parts[3]))

	case ACTION_FIND_DUPLICATES:
		// payload: root|out_path
		parts := split_payload(payload)
		if len(parts) < 2 || len(parts[1]) == 0 do return reply(BAD_PAYLOAD)
		return reply(storage.find_duplicates_to_file(parts[0], parts[1]))

	case ACTION_PLAN_ORGANIZE:
		// payload: root|out_path
		parts := split_payload(payload)
		if len(parts) < 2 || len(parts[1]) == 0 do return reply(BAD_PAYLOAD)
		return reply(storage.plan_organize_to_file(parts[0], parts[1]))

	case ACTION_APPLY_ORGANIZE:
		// payload: plan_path|report_path (pipe-delimited JSON plan → report files)
		parts := split_payload(payload)
		if len(parts) < 2 || len(parts[0]) == 0 || len(parts[1]) == 0 do return reply(BAD_PAYLOAD)
		return reply(storage.apply_organize_file(parts[0], parts[1]))

	case ACTION_GET_CACHED_STATS:
		// payload: cache_path|root|max_age_seconds[|known_device_bytes]
		parts := split_payload(payload)
		if len(parts) < 3 do return reply(BAD_PAYLOAD)
		max_age, _ := strconv.parse_int(parts[2], 10)
		// Fast path: fresh cache → return its path without recomputing
		cached := storage.read_cache_if_fresh(parts[0], max_age)
		if len(cached) > 0 {
			return reply(fmt.tprintf(`{"status":"ok","path":"%s"}`, js_util.json_escape(parts[0])))
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
		// payload: index_path (or "" → use default; handled here as bad_payload)
		if len(payload) == 0 do return reply(BAD_PAYLOAD)
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
		max_days    := 14
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
	return reply(`{"error":"unknown_action"}`)
}

// ---------------------------------------------------------------------------
// JNI-bridged exports — jni/wayer_engine.c calls these directly
// ---------------------------------------------------------------------------

@(export)
wayer_init_engine :: proc "c" () {
	context = runtime.default_context()
	core_heart.info("WayerEngine", "Odin engine initialized")
}

@(export)
wayer_route_action :: proc "c" (action_id: c.int, payload: cstring) -> cstring {
	context = runtime.default_context() // proc "c" has no Odin context; need one
	defer free_all(context.temp_allocator)
	// string(cstring) handles nil gracefully (→ "")
	return route_action(int(action_id), string(payload))
}

// ---------------------------------------------------------------------------
// C ABI exports — individual wayer_* symbols (replace wayer_shim.cpp)
// These are one-to-one with the foreign `wayer_*` procs the Java side used to
// call via the C++ shim. Now Odin owns them; the shim library can be removed
// once all call sites go through wayer_route_action. Kept for compat and for
// native tests that link directly.
// ---------------------------------------------------------------------------

@(export)
wayer_list_files :: proc "c" (path: cstring) -> cstring {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	return reply(storage.list_files(string(path)))
}

@(export)
wayer_get_network_info :: proc "c" () -> cstring {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	return reply(transfer.get_network_info())
}

@(export)
wayer_filter_documents :: proc "c" (payload: cstring) -> cstring {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	return reply(documents.filter_documents(string(payload)))
}

@(export)
wayer_start_listener :: proc "c" (port: c.int) -> cstring {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	return reply(transfer.start_listener(int(port)))
}

@(export)
wayer_search_files_to_file :: proc "c" (root, query, out_path: cstring) -> cstring {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	return reply(storage.search_files_to_file(string(root), string(query), string(out_path)))
}

@(export)
wayer_find_large_files_to_file :: proc "c" (root: cstring, min_bytes: u64, max_results: c.int, out_path: cstring) -> cstring {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	return reply(storage.find_large_files_to_file(string(root), min_bytes, int(max_results), string(out_path)))
}

@(export)
wayer_find_duplicates_to_file :: proc "c" (root, out_path: cstring) -> cstring {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	return reply(storage.find_duplicates_to_file(string(root), string(out_path)))
}

@(export)
wayer_plan_organize_to_file :: proc "c" (root, out_path: cstring) -> cstring {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	return reply(storage.plan_organize_to_file(string(root), string(out_path)))
}

@(export)
wayer_apply_organize_file :: proc "c" (plan_path, report_path: cstring) -> cstring {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	return reply(storage.apply_organize_file(string(plan_path), string(report_path)))
}

@(export)
wayer_read_cache_if_fresh :: proc "c" (cache_path: cstring, max_age: c.int) -> cstring {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	return reply(storage.read_cache_if_fresh(string(cache_path), int(max_age)))
}

@(export)
wayer_read_text_file :: proc "c" (path: cstring, max_bytes: u64) -> cstring {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	return reply(preview.read_text_file(string(path), max_bytes))
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
	return reply(init_app_paths(string(app_root)))
}

@(export)
wayer_json_escape :: proc "c" (s: cstring) -> cstring {
	context = runtime.default_context()
	defer free_all(context.temp_allocator)
	if s == nil do return reply("")
	return reply(js_util.json_escape(string(s)))
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

// Keep media anchor referenced so the media target is not dead-stripped.
// The linker would otherwise drop wayer_media when no Odin symbol uses it.
// We reference it via a no-op call that the optimizer cannot prove is dead
// because it is an exported symbol (visible to C).
@(export)
wayer_media_anchor :: proc "c" () -> c.int {
	context = runtime.default_context()
	return c.int(media.media_module_anchor())
}
