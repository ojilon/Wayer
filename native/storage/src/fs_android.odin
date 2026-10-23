// fs_android.odin — bionic-safe FS foreign imports
// Uses C android_fs.h API (opendir/readdir/stat only, no statx)

package storage

import "core:c"
import "core:fmt"
import "core:strings"

import core_heart "../../core/src"

// C ABI functions from android_fs.c
@(default_calling_convention = "c")
foreign {
	wayer_fs_opendir   :: proc(path: cstring) -> ^WayerFsDir ---
	wayer_fs_readdir   :: proc(d: ^WayerFsDir, out: ^WayerFsEntry) -> c.int ---
	wayer_fs_closedir  :: proc(d: ^WayerFsDir) ---
	wayer_fs_walk_files :: proc(root: cstring, cb: rawptr, ud: rawptr) -> c.int ---
	wayer_fs_stat      :: proc(path: cstring, size_out: ^i64, mtime_out: ^i64, is_dir_out: ^c.int) -> c.int ---
	wayer_fs_mkdir_p   :: proc(path: cstring) -> c.int ---
	wayer_fs_write_file :: proc(path: cstring, data: rawptr, n: c.size_t) -> c.int ---
	wayer_fs_read_file  :: proc(path: cstring, max_bytes: c.size_t, n_out: ^c.size_t) -> rawptr ---
	wayer_fs_rename    :: proc(from, to: cstring) -> c.int ---
	wayer_fs_remove    :: proc(path: cstring) -> c.int ---
}

// C structs mirrored from android_fs.h
WayerFsEntry :: struct {
	name:     cstring,
	name_len: c.size_t,
	is_dir:   c.int,
	size:     i64,
	mtime:    i64,
}

WayerFsDir :: struct {} // opaque

// --- Odin helpers wrapping C FS ---

// C string helper
cs :: proc(s: string) -> cstring {
	return strings.clone_to_cstring(s, context.temp_allocator)
}

// Convert WayerFsEntry.name to Odin string
fs_entry_name :: proc(e: ^WayerFsEntry) -> string {
	return strings.string_from_ptr(cast([^]u8)e.name, int(e.name_len))
}

// List files in a directory (non-recursive) - replaces os.read_dir
list_files_c :: proc(path: string) -> string {
	c_path := cs(path)
	d := wayer_fs_opendir(c_path)
	if d == nil {
		return `{"error":"invalid_directory"}`
	}
	defer wayer_fs_closedir(d)

	sb := strings.builder_make(context.temp_allocator)
	strings.write_string(&sb, `{"files":[`)
	first := true
	ent: WayerFsEntry
	for wayer_fs_readdir(d, &ent) != 0 {
		name := fs_entry_name(&ent)
		if !first { strings.write_string(&sb, ",") }
		first = false
		fmt.sbprintf(&sb, `"%s"`, core_heart.json_escape(name))
	}
	strings.write_string(&sb, "]}")
	return strings.to_string(sb)
}

// Check if path exists and get basic info
stat_c :: proc(path: string) -> (size: i64, mtime: i64, is_dir: bool, ok: bool) {
	c_path := cs(path)
	var sz: i64 = 0
	var mt: i64 = 0
	var is_dir: c.int = 0
	ret := wayer_fs_stat(cs(path), &sz, &mt, &is_dir)
	ok = ret == 0
	return (sz, mt, is_dir == 1, ok)
}

// Create directory (with parents)
mkdir_p_c :: proc(path: string) -> bool {
	return wayer_fs_mkdir_p(cs(path)) == 0
}

// Write file (with parent dirs)
write_file_c :: proc(path: string, data: []u8) -> bool {
	c_path := cs(path)
	ret := wayer_fs_write_file(c_path, data.ptr, data.len)
	return ret == 0
}

// Read file (up to max_bytes, 0 = no limit)
read_file_c :: proc(path: string, max_bytes: usize) -> (data: []u8, ok: bool) {
	c_path := cs(path)
	var n: c.size_t = 0
	buf := wayer_fs_read_file(c_path, c.size_t(max_bytes), &n)
	if buf == nil { return (_, false) }
	defer c.free(buf)
	return (strings.string_from_ptr(cast([^]u8)buf, int(n)), true)
}

// Rename/move file
rename_c :: proc(from, to: string) -> bool {
	return wayer_fs_rename(cs(from), cs(to)) == 0
}

// Delete file
remove_c :: proc(path: string) -> bool {
	return wayer_fs_remove(cs(path)) == 0
}

// Walk files using C FS (bionic-safe)
// Calls `on_file(path, name, size, mtime)` for each regular file
walk_files_c :: proc(root: string, on_file: proc(path: string, name: string, size: i64, mtime: i64)) {
	c_root := cs(root)
	
	// We need a trampoline because C callback expects rawptr
	// Use a context struct passed as user data
	ctx := struct {
		on_file: proc(path: string, name: string, size: i64, mtime: i64),
	}{on_file}
	
	// Trampoline function that matches C callback signature
	extern "c" fn trampoline(path: cstring, name: cstring, size: i64, mtime: i64, ud: rawptr) {
		ctx_ptr := cast(^struct { on_file: proc(path: string, name: string, size: i64, mtime: i64) })ud
		p := strings.string_from_ptr(cast([^]u8)path, -1) // cstring is null-terminated
		n := strings.string_from_ptr(cast([^]u8)name, -1)
		ctx_ptr.on_file(p, n, size, mtime)
	}
	
	_ = wayer_fs_walk_files(cs(root), trampoline, &ctx)
}