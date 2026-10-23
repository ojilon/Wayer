package core_heart

import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"


// AppPaths mirrors wayer::core::AppPaths from paths.hpp
AppPaths :: struct {
	root: string,
	cache: string,
	temp: string,
	logs: string,
}

// DirEnsure mirrors wayer::core::DirEnsure
DirEnsure :: struct {
	path: string,
	existed: bool,
	ready: bool,
}

// AppDirsReport mirrors wayer::core::AppDirsReport
AppDirsReport :: struct {
	paths: AppPaths,
	root: DirEnsure,
	cache: DirEnsure,
	temp: DirEnsure,
	logs: DirEnsure,
}

// Global state for app paths (thread-safe via mutex in C++; Odin uses single-threaded init from JNI)
app_paths: AppPaths
app_paths_initialized: bool

// ensure_one checks/creates a single directory, returns DirEnsure
ensure_one :: proc(dir: string) -> DirEnsure {
	d := DirEnsure{path = dir}
	
	// Check if directory already exists
	info, err := os.stat(dir)
	if err == nil && info.is_dir() {
		d.existed = true
		d.ready = true
		return d
	}
	
	// Create directory (including parents)
	err = os.make_dir(dir)
	if err != nil {
		return d // ready stays false
	}
	
	// Verify it's now a directory
	info, err = os.stat(dir)
	if err == nil && info.is_dir() {
		d.ready = true
	}
	return d
}

// ensure_app_dirs creates root, cache, temp, logs directories
// Mirrors wayer::core::ensure_app_dirs
ensure_app_dirs :: proc(app_root: string) -> AppDirsReport {
	r := AppDirsReport{}
	
	// Normalize root path
	root := strings.trim_right(app_root, "\n\r \t/")
	if len(root) == 0 {
		return r // all fields zeroed
	}
	
	r.paths.root = root
	r.paths.cache = strings.concatenate({root, "/cache"}, context.temp_allocator)
	r.paths.temp = strings.concatenate({root, "/temp"}, context.temp_allocator)
	r.paths.logs = strings.concatenate({root, "/logs"}, context.temp_allocator)
	
	// Ensure root first
	r.root = ensure_one(root)
	
	// Children only attempted when root is usable
	if r.root.ready {
		r.cache = ensure_one(r.paths.cache)
		r.temp = ensure_one(r.paths.temp)
		r.logs = ensure_one(r.paths.logs)
	} else {
		r.cache.path = r.paths.cache
		r.temp.path = r.paths.temp
		r.logs.path = r.paths.logs
	}
	
	return r
}

// write_paths_manifest writes <root>/paths.json manifest
// Mirrors wayer::core::write_paths_manifest
write_paths_manifest :: proc(report: AppDirsReport) -> string {
	if len(report.paths.root) == 0 || !report.root.ready {
		return ""
	}
	
	manifest_path := strings.concatenate({report.paths.root, "/paths.json"}, context.temp_allocator)
	
	sb := strings.builder_make(context.temp_allocator)
	
	// Helper to write bool as "true"/"false"
	write_bool := proc(b: bool) {
		if b {
			strings.write_string(&sb, "true")
		} else {
			strings.write_string(&sb, "false")
		}
	}
	
	fmt.sbprintf(&sb, `{"version":1,"root":"%s","dirs":{"cache":"%s","temp":"%s","logs":"%s"},`,
		json_escape(report.paths.root),
		json_escape(report.paths.cache),
		json_escape(report.paths.temp),
		json_escape(report.paths.logs))
	
	strings.write_string(&sb, `"existed":{"root":`)
	write_bool(report.root.existed)
	strings.write_string(&sb, `,"cache":`)
	write_bool(report.cache.existed)
	strings.write_string(&sb, `,"temp":`)
	write_bool(report.temp.existed)
	strings.write_string(&sb, `,"logs":`)
	write_bool(report.logs.existed)
	strings.write_string(&sb, `},"ready":{"root":`)
	write_bool(report.root.ready)
	strings.write_string(&sb, `,"cache":`)
	write_bool(report.cache.ready)
	strings.write_string(&sb, `,"temp":`)
	write_bool(report.temp.ready)
	strings.write_string(&sb, `,"logs":`)
	write_bool(report.logs.ready)
	strings.write_string(&sb, `}}`)
	
	json := strings.to_string(sb)
	
	// Write to file
	err := os.write_entire_file(manifest_path, transmute([]byte)json)
	if err != nil {
		return ""
	}
	
	return manifest_path
}

// set_app_paths stores the paths globally (called from JNI init)
// Mirrors wayer::core::set_app_paths
set_app_paths :: proc(paths: AppPaths) {
	app_paths = paths
	app_paths_initialized = true
	
	// Ensure directories exist even if caller built AppPaths manually
	if len(paths.cache) > 0 { os.make_dir(paths.cache) }
	if len(paths.temp) > 0 { os.make_dir(paths.temp) }
	if len(paths.logs) > 0 { os.make_dir(paths.logs) }
}

// app_paths returns the stored AppPaths
// Mirrors wayer::core::app_paths
get_app_paths :: proc() -> AppPaths {
	return app_paths
}

// all_ready returns true if all directories are ready
// Mirrors wayer::core::AppDirsReport::all_ready
all_ready :: proc(report: AppDirsReport) -> bool {
	return report.root.ready && report.cache.ready && report.temp.ready && report.logs.ready
}

// app_paths_initialized returns whether set_app_paths has been called
// Mirrors wayer::core::app_paths_initialized
is_app_paths_initialized :: proc() -> bool {
	return app_paths_initialized
}