// =============================================================================
// paths.odin — app-owned directory layout (root/cache/temp/logs)
//
// Part of package core_heart. This is the Odin port of native/core/src/paths.cpp.
// Java passes the private files dir once via ACTION_INIT_APP_PATHS; we create
// the layout and write <root>/paths.json manifest so Java's PathRegistry can
// discover the real paths without re-deriving them.
//
// Layout (mirrors AppDirs.java):
//   <root>/paths.json   manifest {version, root, dirs{cache,temp,logs}, existed, ready}
//   <root>/cache/       storage_stats snapshots, index files, search results
//   <root>/temp/        transfer staging, organize dry-runs
//   <root>/logs/        native.log (C++ side writes; Odin logs to logcat)
//
// Android 10 / bionic abstraction
//   DO NOT use core:os directly for file ops here. The October 2025 Odin
//   core:os update changed allocator signatures and on Android may attempt
//   statx which is blocked by seccomp on API 29 (Android 10). Instead we use
//   the C wrappers in android_fs.c:
//
//     wayer_fs_stat      → stat only (no statx)
//     wayer_fs_mkdir_p   → mkdir -p via mkdir(2)
//     wayer_fs_write_file → open/write/close
//
//   Those wrappers are bionic-safe and tested on Android 10+.
//
// Mirrors: wayer::core::AppPaths, ensure_app_dirs, write_paths_manifest,
//          set_app_paths in native/core/include/wayer/core/paths.hpp
// =============================================================================

package core_heart

import "core:c"
import "core:fmt"
import "core:strings"

import fs "../../file_system_bridge/src"
import js_util "../../json_utils/src"

// ---------------------------------------------------------------------------
// C FS bridge — bionic-safe, no statx (Android 10 seccomp)
// Defined in native/core/src/android_fs.c, linked via wayer_core.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Types — mirror C++ headers (paths.hpp)
// ---------------------------------------------------------------------------

// AppPaths mirrors wayer::core::AppPaths
AppPaths :: struct {
	root:  string,
	cache: string,
	temp:  string,
	logs:  string,
}

// DirEnsure mirrors wayer::core::DirEnsure
DirEnsure :: struct {
	path:    string,
	existed: bool, // already a directory before this call
	ready:   bool, // is a directory now (creation verified)
}

// AppDirsReport mirrors wayer::core::AppDirsReport
AppDirsReport :: struct {
	paths: AppPaths,
	root:  DirEnsure,
	cache: DirEnsure,
	temp:  DirEnsure,
	logs:  DirEnsure,
}

// Global state — set once from JNI. Single-threaded init (Bridge executor
// serializes all native file jobs), so no mutex needed on this side.
app_paths: AppPaths
app_paths_initialized: bool

// ---------------------------------------------------------------------------
// Helpers — use C wrappers for bionic safety
// ---------------------------------------------------------------------------

// cstr clones an Odin string to a NUL-terminated cstring on temp_allocator.
cstr :: proc(s: string) -> cstring {
	return strings.clone_to_cstring(s, context.temp_allocator)
}

// ensure_one checks/creates a single directory using C wrappers.
// Returns DirEnsure with accurate existed/ready flags (not assumed).
ensure_one :: proc(dir: string) -> DirEnsure {
	d := DirEnsure{path = dir}

	// Check if already a directory via C stat (bionic-safe)
	c_path := cstr(dir)
	sz: i64
	mt: i64
	is_dir: c.int
	if fs.wayer_fs_stat(c_path, &sz, &mt, &is_dir) == 0 && is_dir == 1 {
		d.existed = true
		d.ready = true
		return d
	}

	// Create with parents via C mkdir -p
	if fs.wayer_fs_mkdir_p(c_path) != 0 {
		return d // ready stays false
	}

	// Verify it is now a directory
	if fs.wayer_fs_stat(c_path, &sz, &mt, &is_dir) == 0 && is_dir == 1 {
		d.ready = true
	}
	return d
}

// ensure_app_dirs creates root, cache, temp, logs directories.
// Mirrors wayer::core::ensure_app_dirs
ensure_app_dirs :: proc(app_root: string) -> AppDirsReport {
	r := AppDirsReport{}

	// Normalize: trim trailing slashes/whitespace so "/a/b/" and "/a/b" match.
	root := strings.trim_right(app_root, "\n\r \t/")
	if len(root) == 0 {
		return r // all fields zeroed → caller sees !root.ready
	}

	r.paths.root = strings.clone(root, context.temp_allocator)
	r.paths.cache = strings.concatenate({root, "/cache"}, context.temp_allocator)
	r.paths.temp = strings.concatenate({root, "/temp"}, context.temp_allocator)
	r.paths.logs = strings.concatenate({root, "/logs"}, context.temp_allocator)

	// Root first — children only attempted when root is usable.
	r.root = ensure_one(r.paths.root)

	if r.root.ready {
		r.cache = ensure_one(r.paths.cache)
		r.temp  = ensure_one(r.paths.temp)
		r.logs  = ensure_one(r.paths.logs)
	} else {
		// Keep path strings but mark not ready so Java can report accurately.
		r.cache.path = r.paths.cache
		r.temp.path  = r.paths.temp
		r.logs.path  = r.paths.logs
	}

	return r
}

// write_paths_manifest writes <root>/paths.json manifest via C wrapper.
// Mirrors wayer::core::write_paths_manifest
write_paths_manifest :: proc(report: AppDirsReport) -> string {
	if len(report.paths.root) == 0 || !report.root.ready {
		return ""
	}

	manifest_path := strings.concatenate({report.paths.root, "/paths.json"}, context.temp_allocator)

	sb := strings.builder_make(context.temp_allocator)

	// Build JSON manually — no external lib needed for this small manifest.
	// Use json_escape for paths (they may contain spaces/unicode).
	fmt.sbprintf(&sb, `{"version":1,"root":"%s","dirs":{"cache":"%s","temp":"%s","logs":"%s"},`,
		js_util.json_escape(report.paths.root),
		js_util.json_escape(report.paths.cache),
		js_util.json_escape(report.paths.temp),
		js_util.json_escape(report.paths.logs))

	// existed flags
	fmt.sbprintf(&sb, `"existed":{"root":%s,"cache":%s,"temp":%s,"logs":%s},`,
		js_util.bool_to_string(report.root.existed),
		js_util.bool_to_string(report.cache.existed),
		js_util.bool_to_string(report.temp.existed),
		js_util.bool_to_string(report.logs.existed))

	// ready flags
	fmt.sbprintf(&sb, `"ready":{"root":%s,"cache":%s,"temp":%s,"logs":%s}}`,
		js_util.bool_to_string(report.root.ready),
		js_util.bool_to_string(report.cache.ready),
		js_util.bool_to_string(report.temp.ready),
		js_util.bool_to_string(report.logs.ready))

	json := strings.to_string(sb)

	// Write via C wrapper (bionic-safe, creates no temp os.File)
	c_manifest := cstr(manifest_path)
	if fs.wayer_fs_write_file(c_manifest, raw_data(json), len(json)) != 0 {
		return ""
	}

	// Return clone on temp_allocator so caller can embed in reply.
	return strings.clone(manifest_path, context.temp_allocator)
}

// set_app_paths stores the paths globally (called from JNI init).
// Mirrors wayer::core::set_app_paths
set_app_paths :: proc(paths: AppPaths) {
	app_paths = AppPaths{
		root  = strings.clone(paths.root, context.allocator),
		cache = strings.clone(paths.cache, context.allocator),
		temp  = strings.clone(paths.temp, context.allocator),
		logs  = strings.clone(paths.logs, context.allocator),
	}
	app_paths_initialized = true

	// Ensure directories exist even if caller built AppPaths manually.
	if len(app_paths.cache) > 0 {
		fs.wayer_fs_mkdir_p(cstr(app_paths.cache))
	}
	if len(app_paths.temp) > 0 {
		fs.wayer_fs_mkdir_p(cstr(app_paths.temp))
	}
	if len(app_paths.logs) > 0 {
		fs.wayer_fs_mkdir_p(cstr(app_paths.logs))
	}
}

// get_app_paths returns the stored AppPaths (clone for safety).
// Mirrors wayer::core::app_paths()
get_app_paths :: proc() -> AppPaths {
	return app_paths
}

// all_ready returns true if all directories are ready.
// Mirrors AppDirsReport::all_ready()
all_ready :: proc(report: AppDirsReport) -> bool {
	return report.root.ready && report.cache.ready && report.temp.ready && report.logs.ready
}

// is_app_paths_initialized returns whether set_app_paths has been called.
// Mirrors wayer::core::app_paths_initialized()
is_app_paths_initialized :: proc() -> bool {
	return app_paths_initialized
}
