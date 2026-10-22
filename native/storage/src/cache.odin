package storage

import "core:os"
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
		os.make_dir(parent)
	}
	
	os.write_entire_file(cache_path, transmute([]byte)json)
}

// read_cache_if_fresh reads cache if it exists and is not older than max_age_seconds
// Returns "" if missing or stale
// Mirrors wayer::storage::read_cache_if_fresh
read_cache_if_fresh :: proc(cache_path: string, max_age_seconds: int) -> string {
	if max_age_seconds <= 0 { return "" }
	
	info, err := os.stat(cache_path)
	if err != nil { return "" }
	
	// Use unix timestamps for comparison
	mtime := info.mod_time().unix() // seconds since epoch
	now := time.now().unix()
	age := now - mtime
	
	if age > i64(max_age_seconds) {
		return ""
	}
	
	data, err := os.read_entire_file(cache_path)
	if err != nil { return "" }
	
	return string(data)
}

// invalidate_cache deletes a cache file
// Mirrors wayer::storage::invalidate_cache
invalidate_cache :: proc(cache_path: string) -> bool {
	err := os.remove(cache_path)
	return err == nil
}