#pragma once
// odin_bionic_shim.h — C wrapper contract for Odin ↔ Android bionic
//
// Why this file exists (Oct 2025 sweep)
//   Odin `core:os` may emit `statx`/`openat2` on Android, which seccomp blocks
//   on API 29 (Android 10). All Odin file I/O must go through the allowlisted
//   C wrappers below, not `core:os` or `std::filesystem`.
//
// Allowlist (bionic-safe, tested on Android 10 device + host)
//   opendir, readdir, closedir
//   stat (never statx)
//   open (O_RDONLY/WRONLY|CREAT|TRUNC), read, write, close
//   mkdir (looped for -p, never mkdirat with AT_FDCWD)
//   rename, unlink
//   time(2), free (for C-allocated read buffers)
//
// Implementations
//   * Single-file ops:    native/core/src/android_fs.c  (WayerFsDir, wayer_fs_*)
//   * Recursive walks:    native/storage/src/dir_walk_android.c (WayerDir/wayer_dir_*)
//   * Index (streaming):  native/storage/src/index_c.c  (BUILD_INDEX, SEARCH_INDEX, GROUP_BY_DAY)
//   * Walk collecting:    native/storage/src/collect_data.c + check_if_directory.c
//
// Odin usage (see native/storage/src/fs_android.odin for the canonical example)
//
//   package storage
//   import core_heart "../../core/src"
//   foreign import android_fs "system:c"
//   @(default_calling_convention="c")
//   foreign android_fs {
//       wayer_fs_stat :: proc(path: cstring, size_out: ^i64, mtime_out: ^i64, is_dir_out: ^c.int) -> c.int ---
//       wayer_fs_mkdir_p :: proc(path: cstring) -> c.int ---
//       // ... etc.
//   }
//   // then
//   stat_c :: proc(path: string) -> (size, mtime, is_dir, ok) { c_path := cs(path); ... wayer_fs_stat(c_path, &sz, &mt, &is_dir) ... }
//
// Do NOT call
//   os.stat, os.read_dir, os.write_entire_file, std::filesystem::*, or any
//   Odin proc that internally may use statx on Android. Use the wrappers above.
//
// See docs/NATIVE_OVERVIEW.md §4 for the full table per proc/header.
