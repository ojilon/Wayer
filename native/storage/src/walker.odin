// =============================================================================
// walker.odin — shared recursive walk for Storage stats
//
// Part of package storage. This is the Odin port of native/storage/src/walker.cpp.
// It accumulates category totals and per-top-folder sizes in a single walk so
// analyse_storage_space.odin doesn't need to walk twice.
//
// How it works
//   * Uses the bionic-safe WayerDir API from dir_walk_android.c (opendir/
//     readdir/stat only, no statx) via the foreign block below.
//   * `Scan.top` is the name of the top-level child we are currently inside;
//     files directly under the root have top == "" and count toward categories
//     only, not toward any top folder.
//   * Excluded directories (see safety.odin) are never descended into.
//
// Android 10 / bionic: WayerDir is depth-limited (32) and path-capped (512)
// to avoid stack overflow on deep trash hierarchies.
//
// Mirrors: wayer::storage::walk_files, Scan in native/storage/src/walker.cpp
//          analyse_storage_space.cpp uses Scan to build StorageNumbers
// =============================================================================

package storage

import "core:c"
import "core:strings"

// ---------------------------------------------------------------------------
// C ABI — dir_walk_android.c (not android_fs.c; separate walker for stats)
// ---------------------------------------------------------------------------

foreign import walker_c "system:c"

@(default_calling_convention = "c")
foreign walker_c {
	wayer_dir_open  :: proc(path: cstring) -> ^WayerDir ---
	wayer_dir_next  :: proc(dir: ^WayerDir, out: ^WayerDirEntry) -> c.int ---
	wayer_dir_close :: proc(dir: ^WayerDir) ---
}

// Structs must match dir_walk_android.h
WayerDirEntry :: struct {
	name:     cstring,
	name_len: c.size_t,
	is_dir:   c.int, // 1 dir, 0 file, -1 other
	size:     i64,
}

WayerDir :: struct {} // opaque handle

// ---------------------------------------------------------------------------
// Accumulator — passed by pointer through recursion (replaces C++ lambda capture)
// ---------------------------------------------------------------------------

// Scan collects what the walk finds. Passing ^Scan replaces the C++ lambda.
Scan :: struct {
	categories: [Category]u64,  // per Category total bytes
	top_dirs:   map[string]u64, // top-level folder → total bytes
}

// scan_dir recursively walks `dir` (full path) and accumulates into `scan`.
// `top` is the top-level folder name we are inside; "" means root.
scan_dir :: proc(scan: ^Scan, dir: string, top: string) {
	c_dir := strings.clone_to_cstring(dir, context.temp_allocator)
	handle := wayer_dir_open(c_dir)
	if handle == nil {
		return // unreadable — same as old error_code skip
	}
	defer wayer_dir_close(handle)

	ent: WayerDirEntry
	for wayer_dir_next(handle, &ent) != 0 {
		// ent.name is cstring with exact name_len
		name := string(([^]u8)(ent.name)[:ent.name_len])

		if ent.is_dir == 1 {
			if is_excluded_dir(name, dir) {
				continue
			}
			child     := strings.concatenate({dir, "/", name}, context.temp_allocator)
			child_top := name if top == "" else top
			scan_dir(scan, child, child_top)
			continue
		}

		if ent.is_dir != 0 {
			continue // not a regular file (is_dir == -1)
		}

		size := u64(max(ent.size, 0))
		scan.categories[category_for_name(name)] += size

		if top != "" {
			// Clone `top` into allocator that outlives this call.
			// Use temp_allocator (per-JNI call) — safe because the map is
			// consumed before wayer_core.odin frees temp_allocator.
			if top not_in scan.top_dirs {
				// Need to clone key since `top` string may be temp-allocated
				// per recursion frame; the map must own its keys.
				cloned := strings.clone(top, context.temp_allocator)
				scan.top_dirs[cloned] = 0
			}
			scan.top_dirs[top] += size
		} else {
			// Direct child of root: still track as top_dir for completeness
			// if caller wants "root files" bucket. We skip to match C++ which
			// only tracks top-level directories, not root files.
		}
	}
}
