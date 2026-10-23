package storage

import "core:c"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

import core_heart "../../core/src"


RETAIL_64GB :: u64(64_000_000_000)
kMaxFolders :: 100

// ───────────── statvfs from libc (bionic, LP64 layout) ─────────────

foreign import libc "system:c"

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
	_reserved: [6]u32,
}

@(default_calling_convention = "c")
foreign libc {
	statvfs :: proc(path: cstring, buf: ^Statvfs) -> c.int ---
}


// ───────────── Main entry ─────────────

write_storage_stats :: proc(root_path: string, out_path: string, known_device_bytes: u64) -> string {
	// 1. Partition metrics from the OS
	stat: Statvfs
	c_root := strings.clone_to_cstring(root_path, context.temp_allocator) // Odin strings aren't NUL-terminated
	if statvfs(c_root, &stat) != 0 {
		return `{"status":"error","reason":"statvfs_failed"}`
	}

	partition_total := u64(stat.f_blocks) * u64(stat.f_frsize)
	free_bytes      := u64(stat.f_bavail) * u64(stat.f_frsize)
	partition_used  := partition_total - free_bytes if partition_total > free_bytes else 0

	// Prefer the real capacity from Java; otherwise fall back to the retail floor.
	device_total := known_device_bytes
	if device_total == 0 {
		device_total = max(partition_total, RETAIL_64GB)
	}
	device_total = max(device_total, partition_total)

	system_bytes := device_total - partition_total if device_total > partition_total else 0
	used_bytes   := partition_used + system_bytes

	// 2. One walk feeds both the category totals and the per-top-folder sizes
	scan := Scan{ top_dirs = make(map[string]u64, context.temp_allocator) }
	root := strings.trim_right(root_path, "/") // so "/a/b/" and "/a/b" behave the same
	scan_dir(&scan, root, "")

	// 3. Top folders, biggest first, capped
	folders := make([dynamic]FolderStat, context.temp_allocator)
	for name, bytes in scan.top_dirs {
		append(&folders, FolderStat{name = name, bytes = bytes})
	}
	slice.sort_by(folders[:], proc(a, b: FolderStat) -> bool { return a.bytes > b.bytes })
	top_folders := folders[:min(len(folders), kMaxFolders)]

	// 4. Assemble the numbers
	numbers := StorageNumbers{
		total_bytes      = device_total,
		used_bytes       = used_bytes,
		free_bytes       = free_bytes,
		progress_percent = int((used_bytes * 100) / device_total) if device_total > 0 else 0,
		images           = scan.categories[.Images],
		videos           = scan.categories[.Videos],
		audio            = scan.categories[.Audio],
		documents        = scan.categories[.Documents],
		foreign_files    = scan.categories[.Foreign_Files],
		system           = system_bytes,
		others           = scan.categories[.Others],
		folders          = top_folders,
	}

	json := build_stats_json(numbers)

	// TODO: stats_db_record(root_path, device_total, used_bytes) once stats_db is ported.
	// It was best-effort in C++, so skipping it can't break the snapshot.

	// Write the JSON snapshot to the cache path
	if !fs.write_file_c(out_path, transmute([]u8)json) {
		return `{"status":"error","reason":"write_failed"}`
	}
	// Success: tell Java where the fresh snapshot lives.
	return fmt.tprintf(`{"status":"ok","path":"%s"}`, core_heart.json_escape(out_path))
}