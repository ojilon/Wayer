// =============================================================================
// analyse_storage_space.odin — storage stats via statvfs + single walk
//
// Part of package storage. Computes total/used/free bytes for a root path,
// plus per-category totals (Images, Videos, …) and per-top-folder sizes.
// The result is written as JSON to a cache file; JNI returns {status, path}.
//
// How it works
//   1. Partition metrics from statvfs(2) (bionic's statvfs is safe on API 29;
//      we call it via libc FFI, not via core:os which might use statx).
//   2. One walk (walker.odin) feeds both category totals and top-folder sizes.
//   3. Top folders are sorted biggest-first, capped at 100.
//   4. StorageNumbers → JSON via stats_json.odin → file via C wrapper.
//   5. SQLite history row is best-effort (stats_db.odin) — failure never fails
//      the snapshot (same as C++).
//
// Device capacity quirk
//   statvfs's f_blocks*f_frsize is the *partition* size (e.g. /data). Java
//   passes the real device capacity (getTotalBytes) as known_device_bytes when
//   available; otherwise we fall back to max(partition, 64 GB retail floor).
//   The difference is the "system" bucket shown in the Storage screen.
//
// Android 10 / bionic
//   * statvfs is a bionic libc call — safe on API 29 (no statx).
//   * Walking uses WayerDir (dir_walk_android.c), not core:os.
//   * File write uses wayer_fs_write_file, not os.write_entire_file.
//
// Mirrors: wayer::storage::write_storage_stats in analyse_storage_space.cpp
//          StorageNumbers / build_stats_json
// =============================================================================

package storage

import "core:c"
import "core:fmt"
import "core:slice"
import "core:strings"

import core_heart "../../core/src"
import fs "../../file_system_bridge/src"
import js_util "../../json_utils/src"

// Retail floor — worst-case capacity for phones that don't report real size.
RETAIL_64GB :: u64(64_000_000_000)
kMaxFolders :: 100

// ---------------------------------------------------------------------------
// statvfs — bionic's struct layout is LP64; we mirror the NDK header.
// ---------------------------------------------------------------------------

foreign import libc "system:c"

// Statvfs mirrors `struct statvfs` from <sys/statvfs.h> on bionic LP64.
// Field order matches NDK's sys/statvfs.h for arm64.
Statvfs :: struct {
	f_bsize:   c.ulong,
	f_frsize:  c.ulong,
	f_blocks:  c.ulong,
	f_bfree:   c.ulong,
	f_bavail:  c.ulong,
	f_files:   c.ulong,
	f_ffree:   c.ulong,
	f_favail:  c.ulong,
	f_fsid:    c.ulong,
	f_flag:    c.ulong,
	f_namemax: c.ulong,
	_reserved: [6]u32, // padding for future
}

@(default_calling_convention = "c")
foreign libc {
	statvfs :: proc(path: cstring, buf: ^Statvfs) -> c.int ---
}

// ---------------------------------------------------------------------------
// Main entry — write_storage_stats
// ---------------------------------------------------------------------------

// write_storage_stats computes stats for root_path and spills JSON to out_path.
// Returns a small JSON reply; Java reads the snapshot file for the full data.
// Mirrors wayer::storage::write_storage_stats(root, out_path, known_bytes)
write_storage_stats :: proc(root_path: string, out_path: string, known_device_bytes: u64) -> string {
	if len(root_path) == 0 || len(out_path) == 0 {
		return `{"status":"error","reason":"bad_payload"}`
	}

	// 1. Partition metrics from OS
	stat: Statvfs
	c_root := strings.clone_to_cstring(root_path, context.temp_allocator)
	if statvfs(c_root, &stat) != 0 {
		return `{"status":"error","reason":"statvfs_failed"}`
	}

	partition_total := u64(stat.f_blocks) * u64(stat.f_frsize)
	free_bytes      := u64(stat.f_bavail) * u64(stat.f_frsize)
	partition_used  := 0 if partition_total < free_bytes else partition_total - free_bytes

	// Prefer Java's real capacity; otherwise floor to retail 64 GB.
	device_total := known_device_bytes
	if device_total == 0 {
		device_total = max(partition_total, RETAIL_64GB)
	}
	device_total = max(device_total, partition_total)

	system_bytes := 0 if device_total < partition_total else device_total - partition_total
	used_bytes   := partition_used + system_bytes

	// 2. One walk feeds both category totals and per-top-folder sizes.
	scan := Scan{top_dirs = make(map[string]u64, context.temp_allocator)}
	root := strings.trim_right(root_path, "/")
	scan_dir(&scan, root, "")

	// 3. Top folders, biggest first, capped.
	folders := make([dynamic]js_util.FolderStat, context.temp_allocator)
	for name, bytes in scan.top_dirs {
		append(&folders, js_util.FolderStat{name = name, bytes = bytes})
	}
	slice.sort_by(folders[:], proc(a, b: js_util.FolderStat) -> bool {
		return a.bytes > b.bytes
	})
	limit := min(len(folders), kMaxFolders)
	top_folders := folders[:limit]

	// 4. Assemble numbers struct
	numbers := js_util.StorageNumbers{
		total_bytes      = device_total,
		used_bytes       = used_bytes,
		free_bytes       = free_bytes,
		progress_percent = 0 if device_total == 0 else int((used_bytes * 100) / device_total),
		images           = scan.categories[.Images],
		videos           = scan.categories[.Videos],
		audio            = scan.categories[.Audio],
		documents        = scan.categories[.Documents],
		foreign_files    = scan.categories[.Foreign_Files],
		system           = system_bytes,
		others           = scan.categories[.Others],
		folders          = top_folders,
	}

	json := js_util.build_stats_json(numbers)

	// 5. Best-effort SQLite history row (failure is silent, same as C++)
	// Deferred until after stats_db is ported — currently no-op if uninitialized.
	// stats_db_record(root_path, device_total, used_bytes)

	// 6. Write snapshot to cache path via C wrapper (bionic-safe)
	if !fs.write_file_c(out_path, transmute([]u8)json) {
		return `{"status":"error","reason":"write_failed"}`
	}

	// Success: tell Java where the fresh snapshot lives.
	return fmt.tprintf(`{"status":"ok","path":"%s"}`, js_util.json_escape(out_path))
}
