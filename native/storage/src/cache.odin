package storage

import "core:time"

import core_heart "../../core/src"

// write_cache writes JSON to a cache file, creating parent directories
// Mirrors wayer::storage::write_cache
write_cache :: proc(cache_path: string, json: string) {
	// Find parent directory
	last_slash := -1
	for i := 0; i < len(cache_path); i++ {
		if cache_path[i] == '/' || cache_path[i] == '\\' {
			last_slash = i
		}
	}
	if last_slash > 0 {
		parent := cache_path[:last_slash]
		fs.mkdir_p_c(parent)
	}
	
	fs.write_file_c(cache_path, transmute([]u8)json)
}

// read_cache_if_fresh reads cache if it exists and is not older than max_age_seconds
// Returns "" if missing or stale
// Mirrors wayer::storage::read_cache_if_fresh
read_cache_if_fresh :: proc(cache_path: string, max_age_seconds: int) -> string {
	if max_age_seconds <= 0 { return "" }
	
	_, mtime, _, ok := fs.stat_c(cache_path)
	if !ok { return "" }
	
	// Use unix timestamps for comparison
	now := time.now().unix()
	age := now - mtime
	
	if age > i64(max_age_seconds) {
		return ""
	}
	
	data, ok := fs.read_file_c(cache_path, 1024 * 1024) // 1MB max
	if !ok { return "" }
	
	return data
}

// invalidate_cache deletes a cache file
// Mirrors wayer::storage::invalidate_cache
invalidate_cache :: proc(cache_path: string) -> bool {
	return fs.remove_c(cache_path)
}