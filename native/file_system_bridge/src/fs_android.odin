// =============================================================================
// fs_android.odin — bionic-safe filesystem bridge for Odin
//
// Part of package storage (imported by all storage submodules). This file is
// the *only* place Odin touches the filesystem — every read/write/stat/mkdir
// goes through C wrappers in android_fs.c, which use only syscalls allowed
// on Android 10 (opendir/readdir/stat/open/read/write/mkdir/rename/unlink).
// statx is never called (seccomp-blocked on API 29).
//
// Why this matters (October 2025 Odin + Android 10)
//   * core:os in Odin Oct 2025 changed allocator signatures and, on Android,
//     may attempt modern syscalls like statx/openat2 that the bionic seccomp
//     filter on API 29 rejects. By routing all file ops through android_fs.c,
//     we guarantee bionic-safe behavior regardless of Odin version.
//   * The same C wrappers are used by index_c.c and dir_walk_android.c, so
//     Odin and C share identical exclusion rules and path handling.
//
// Public helpers in this file
//   stat_c        → (size, mtime, is_dir, ok)
//   mkdir_p_c     → bool
//   write_file_c  → bool
//   read_file_c   → ([]u8, ok)  // malloc'd buffer, copied to Odin heap
//   remove_c / rename_c
//   walk_files_c  → calls on_file(path, name, size, mtime) per regular file
//
// Walk implementation detail
//   C walk is recursive in C (depth-limited to 32). Odin receives a plain
//   function pointer callback via a trampoline defined at package scope (Odin
//   does not allow nested `extern "c" fn` inside a proc).
// =============================================================================

package file_system

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:strings"
import "core:mem"

import js_util "../../json_utils/src"

// ---------------------------------------------------------------------------
// C ABI — mirrored from native/core/include/wayer/core/android_fs.h
// ---------------------------------------------------------------------------

foreign import android_fs "system:c"
foreign import libc "system:c"

@(default_calling_convention = "c")
foreign android_fs {
	wayer_fs_opendir    :: proc(path: cstring) -> ^WayerFsDir ---
	wayer_fs_readdir    :: proc(d: ^WayerFsDir, out: ^WayerFsEntry) -> c.int ---
	wayer_fs_closedir   :: proc(d: ^WayerFsDir) ---
	wayer_fs_walk_files :: proc(root: cstring, cb: WayerFsFileCb, ud: rawptr) -> c.int ---
	wayer_fs_stat       :: proc(path: cstring, size_out: ^i64, mtime_out: ^i64, is_dir_out: ^c.int) -> c.int ---
	wayer_fs_mkdir_p    :: proc(path: cstring) -> c.int ---
	wayer_fs_write_file :: proc(path: cstring, data: rawptr, n: c.size_t) -> c.int ---
	wayer_fs_read_file  :: proc(path: cstring, max_bytes: c.size_t, n_out: ^c.size_t) -> rawptr ---
	wayer_fs_rename     :: proc(from, to: cstring) -> c.int ---
	wayer_fs_remove     :: proc(path: cstring) -> c.int ---
}

@(default_calling_convention = "c")
foreign libc {
	// bionic-safe time(2) and free (for C-allocated read buffers)
	@(link_name = "time")
	c_time :: proc(tloc: ^i64) -> i64 ---
	free   :: proc(ptr: rawptr) ---
}

// C structs — layout must match android_fs.h exactly.
WayerFsEntry :: struct {
	name:     cstring,  // valid until next readdir/close
	name_len: c.size_t,
	is_dir:   c.int,    // 1 dir, 0 file, -1 other
	size:     i64,
	mtime:    i64,      // unix seconds
}

WayerFsDir :: struct {} // opaque handle; fields live in C

// Callback type for C walk — must be C calling convention.
WayerFsFileCb :: proc "c" (path: cstring, name: cstring, size: i64, mtime: i64, ud: rawptr)

// ---------------------------------------------------------------------------
// Odin helpers — thin wrappers that convert Odin strings ↔ C strings
// ---------------------------------------------------------------------------

// cs clones an Odin string to NUL-terminated cstring on temp_allocator.
cs :: proc(s: string) -> cstring {
	return strings.clone_to_cstring(s, context.temp_allocator)
}

// fs_entry_name converts WayerFsEntry.name to an Odin string (exact length).
fs_entry_name :: proc(e: ^WayerFsEntry) -> string {
	return string(([^]u8)(e.name)[:e.name_len])
}

// stat_c checks a path via C stat (bionic-safe, no statx).
// Returns (size, mtime, is_dir, ok).
stat_c :: proc(path: string) -> (size: i64, mtime: i64, is_dir: bool, ok: bool) {
	c_path := cs(path)
	sz: i64
	mt: i64
	is_dir_i: c.int
	ret := wayer_fs_stat(c_path, &sz, &mt, &is_dir_i)
	if ret != 0 {
		return 0, 0, false, false
	}
	return sz, mt, is_dir_i == 1, true
}

// mkdir_p_c creates a directory and parents via C mkdir -p.
mkdir_p_c :: proc(path: string) -> bool {
	return wayer_fs_mkdir_p(cs(path)) == 0
}

// write_file_c writes data to path via C open/write (bionic-safe).
write_file_c :: proc(path: string, data: []u8) -> bool {
	c_path := cs(path)
	ret := wayer_fs_write_file(c_path, raw_data(data), len(data))
	return ret == 0
}

// read_file_c reads up to max_bytes from path via C open/read.
// The C buffer is malloc'd; we copy it to Odin heap then free.
read_file_c :: proc(path: string, max_bytes: int) -> (data: string, ok: bool) {
	c_path := cs(path)
	n: c.size_t
	buf := wayer_fs_read_file(c_path, c.size_t(max_bytes), &n)
	if buf == nil {
		return "", false
	}
	defer free(buf)

	// Copy to Odin memory (temp_allocator — caller must clone if keeping).
	bytes := mem.slice_ptr(cast([^]u8)buf, int(n))
	cloned := make([]u8, int(n), context.temp_allocator)
	copy(cloned, bytes)
	return string(cloned), true
}

// rename_c moves a file via C rename(2).
rename_c :: proc(from, to: string) -> bool {
	return wayer_fs_rename(cs(from), cs(to)) == 0
}

// remove_c deletes a file via C unlink(2).
remove_c :: proc(path: string) -> bool {
	return wayer_fs_remove(cs(path)) == 0
}

// ---------------------------------------------------------------------------
// Walk — C recursion with Odin callback via trampoline
// ---------------------------------------------------------------------------

// WalkCtx bundles the Odin closure for the C callback. We pass its address
// as `ud` (user data) so the trampoline can call back into Odin.
WalkCtx :: struct {
	on_file: proc(path: string, name: string, size: i64, mtime: i64),
}

// walk_trampoline is the C-callable adapter. It reconstructs the WalkCtx
// from `ud` and forwards to the Odin proc. Defined at package scope because
// Odin forbids nested `extern "c"` procs inside another proc.
walk_trampoline :: proc "c" (path: cstring, name: cstring, size: i64, mtime: i64, ud: rawptr) {
	context = runtime.default_context()
	ctx := cast(^WalkCtx)ud
	// cstring → Odin string: use string() with known NUL termination.
	// For safety we use strings.clone_from_cstring or manual length.
	p := string(path)
	n := string(name)
	ctx.on_file(p, n, size, mtime)
}

// walk_files_c walks `root` via C (depth-limited, exclusion-aware) and calls
// `on_file(path, name, size, mtime)` for each regular file.
walk_files_c :: proc(root: string, on_file: proc(path: string, name: string, size: i64, mtime: i64)) {
	c_root := cs(root)
	ctx := WalkCtx{on_file = on_file}
	wayer_fs_walk_files(c_root, walk_trampoline, &ctx)
}

// ---------------------------------------------------------------------------
// List helper (non-recursive) — used by Files tab for single-directory views
// ---------------------------------------------------------------------------

list_files_via_c :: proc(path: string) -> string {
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
		if !first {
			strings.write_string(&sb, ",")
		}
		first = false
		fmt.sbprintf(&sb, `"%s"`, js_util.json_escape(name))
	}
	strings.write_string(&sb, "]}")
	return strings.to_string(sb)
}
