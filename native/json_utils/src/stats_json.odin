// =============================================================================
// stats_json.odin — storage stats document model + JSON writer
//
// Part of package storage. Defines the shape of the Storage stats snapshot
// that HomeFragment and StorageFragment parse, and writes it as JSON.
//
// Document shape (field names match what Java has always parsed):
//   {
//     "total_bytes": 128000000000,
//     "used_bytes":  64000000000,
//     "free_bytes":  64000000000,
//     "progress_percent": 50,
//     "breakdown": { "images":..., "videos":..., "audio":..., "documents":...,
//                    "foreign":..., "system":..., "others":... },
//     "folders": [ {"path":"DCIM","bytes":...}, ... ]  // top_dirs, biggest first
//   }
//
// Why hand-build JSON for stats but use nlohmann/json on C++ side?
//   The C++ side already uses the JSON lib for stats (per-app/for-folder
//   detail may grow). Odin's document is intentionally minimal and stable —
//   Java parses it with org.json.JSONObject, so we keep the shape identical.
//
// Mirrors: wayer::storage::StorageNumbers, FolderStat, build_stats_json
//          in native/storage/src/stats_json.cpp
// =============================================================================

package json_util

import "core:strings"
import "core:fmt"

// ---------------------------------------------------------------------------
// Types — mirror stats_json.hpp
// ---------------------------------------------------------------------------

FolderStat :: struct {
	name:  string,
	bytes: u64,
}

StorageNumbers :: struct {
	total_bytes:      u64,
	used_bytes:       u64,
	free_bytes:       u64,
	progress_percent: int,
	images:           u64,
	videos:           u64,
	audio:            u64,
	documents:        u64,
	foreign_files:    u64, // `foreign` is an Odin keyword
	system:           u64,
	others:           u64,
	folders:          []FolderStat,
}

// build_stats_json serializes StorageNumbers to a JSON string on temp_allocator.
// Field order matches C++ build_stats_json so Java parsing is identical.
build_stats_json :: proc(n: StorageNumbers) -> string {
	sb := strings.builder_make(context.temp_allocator)

	fmt.sbprintf(&sb, `{"total_bytes":%d,"used_bytes":%d,"free_bytes":%d,"progress_percent":%d,`,
		n.total_bytes, n.used_bytes, n.free_bytes, n.progress_percent)

	fmt.sbprintf(&sb, `"breakdown":{"images":%d,"videos":%d,"audio":%d,"documents":%d,"foreign":%d,"system":%d,"others":%d},`,
		n.images, n.videos, n.audio, n.documents, n.foreign_files, n.system, n.others)

	strings.write_string(&sb, `"folders":[`)

	// NOTE: Odin `for folder, i in n.folders` gives value then index; we use index-aware loop.
	for i := 0; i < len(n.folders); i += 1 {
		folder := n.folders[i]
		if i > 0 {
			strings.write_string(&sb, ",")
		}
		fmt.sbprintf(&sb, `{"path":"%s","bytes":%d}`, json_escape(folder.name), folder.bytes)
	}
	strings.write_string(&sb, "]}")

	return strings.to_string(sb)
}
