// =============================================================================
// cache.odin — file-backed cache for stats/index JSON blobs
//
// Part of package storage. Storage stats snapshots and other computed JSON
// are spilled to files under the private app cache (e.g. <root>/cache/stats_*.json).
// Java reads them via PathCache.readFile; JNI only returns {status, path}.
//
// Why file-backed?
//   * JNI strings are limited and copying large JSON over the boundary is slow.
//   * The file is the shared memory between native and Java — both sides can
//     re-read it without another native call (see NativeCache.java).
//   * Leases (FileLeases.java) serialize writers so two jobs never stomp the
//     same cache file.
//
// Android 10 / bionic: All ops use wayer_fs_* C wrappers (no statx).
//
// Mirrors: wayer::storage::write_cache, read_cache_if_fresh, invalidate_cache
//          in native/storage/src/storage_cache.cpp
// =============================================================================

package storage

import "core:strings"

import core_heart "../../core/src"
import fs "../../file_system_bridge/src"

// write_cache writes JSON to a cache file, creating parent directories via C.
// Mirrors wayer::storage::write_cache
write_cache :: proc(cache_path: string, json: string) {
	if len(cache_path) == 0 {
		return
	}

	// Extract parent directory (everything before last slash)
	last_slash := -1
	for i in 0 ..< len(cache_path) {
		if cache_path[i] == '/' || cache_path[i] == '\\' {
			last_slash = i
		}
	}
	if last_slash > 0 {
		parent := cache_path[:last_slash]
		fs.mkdir_p_c(parent) // C mkdir -p, bionic-safe
	}

    fs.write_file_c(cache_path, transmute([]u8)json)
}

// read_cache_if_fresh returns cached JSON if file exists and is not older than
// max_age_seconds. Returns "" when missing, stale, or unreadable.
// max_age_seconds <= 0 always forces recompute (caller passes 0 for refresh).
// Mirrors wayer::storage::read_cache_if_fresh
read_cache_if_fresh :: proc(cache_path: string, max_age_seconds: int) -> string {
	if max_age_seconds <= 0 {
		return ""
	}
	if len(cache_path) == 0 {
		return ""
	}

	_, mtime, _, ok := fs.stat_c(cache_path)
	if !ok {
		return ""
	}

	// Age check via unix timestamps (mtime from C stat, now from C time(2))
	now := fs.c_time(nil) // C time(nil) → current unix seconds, bionic-safe
	age := now - mtime
	if age > i64(max_age_seconds) {
		return ""
	}

	// Read file (1 MiB cap — stats snapshots are ~2-10 KiB)
	data, ok2 := fs.read_file_c(cache_path, 1024 * 1024)
	if !ok2 {
		return ""
	}
	return data
}

// invalidate_cache deletes a cache file after a mutation (delete/organize).
// Mirrors wayer::storage::invalidate_cache
invalidate_cache :: proc(cache_path: string) -> bool {
	if len(cache_path) == 0 {
		return false
	}
	return fs.remove_c(cache_path)
}
