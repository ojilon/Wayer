package storage

import "core:c"
import "core:strings"

// ---- C bridge (dir_walk_android.c) — no Odin os.read_dir / no statx ----

WayerDirEntry :: struct {
	name:     cstring,
	name_len: c.size_t,
	is_dir:   c.int,    // 1 dir, 0 file, -1 other
	size:     i64,
}

WayerDir :: struct {} // opaque

foreign import storage_c "system:wayer_storage"  // linked via CMake as part of the .so

@(default_calling_convention = "c")
foreign storage_c {
	wayer_dir_open  :: proc(path: cstring) -> ^WayerDir ---
	wayer_dir_next  :: proc(dir: ^WayerDir, out: ^WayerDirEntry) -> c.int ---
	wayer_dir_close :: proc(dir: ^WayerDir) ---
}

// Everything the walk accumulates. Passing ^Scan around replaces the C++ lambda capture.
Scan :: struct {
	categories: [Category]u64,
	top_dirs:   map[string]u64,
}

// `top` is the name of the top-level folder we are inside.
// "" means we're directly in the root, so files here count toward categories only.
scan_dir :: proc(scan: ^Scan, dir: string, top: string) {
	c_dir := strings.clone_to_cstring(dir, context.temp_allocator)
	handle := wayer_dir_open(c_dir)
	if handle == nil {
		return //unreadable, same as old error_code skip
	}
	defer wayer_dir_close(handle)

	ent: WayerDirEntry
	for wayer_dir_next(handle, &ent) != 0 {
		// name from C is a cstring; take exact length
		name := strings.string_from_ptr(cast([^]u8)ent.name, int(ent.name_len))
	
		if ent.is_dir == 1 {
			if is_excluded_dir(name, dir) {
				continue
			}
			child := strings.concatenate({dir, "/", name}, context.temp_allocator)
			child_top := top if top != "" else name
			scan_dir(scan, child, child_top)
			continue
		}
	
		if ent.is_dir != 0 {
			continue // not a regular file
		}
	
		size := u64(max(ent.size, 0))
		scan.categories[category_for_name(name)] += size
	
		if top != "" {
			if top not_in scan.top_dirs {
				scan.top_dirs[strings.clone(top, context.temp_allocator)] = 0
			}
			scan.top_dirs[top] += size
		}
	}
}
