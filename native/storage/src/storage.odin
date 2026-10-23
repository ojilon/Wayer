// =============================================================================
// storage.odin — package facade for the storage module
//
// Part of package storage (wayer_storage). This file re-exports the public
// surface so wayer_core.odin can import a single package `storage` and call
// any submodule procedure. In Odin, all files in the same package share a
// namespace, so these aliases are *not* aliases to other packages — they are
// convenience names that forward to the actual implementations in sibling files.
//
// Why this exists
//   * Documents which submodules are public.
//   * Provides a single import for wayer_core.odin: `import storage "../storage/src"`.
//   * No qualifier needed — all symbols are already in package storage.
//
// Module map
//   extension_map.odin     → Category, category_for_name/extension
//   fs_android.odin        → bionic-safe FS wrappers (stat_c, walk_files_c, etc.)
//   safety.odin            → is_excluded_dir
//   walker.odin            → Scan, scan_dir (directory walk for stats)
//   stats_json.odin         → StorageNumbers, FolderStat, build_stats_json
//   analyse_storage_space.odin → write_storage_stats (uses statvfs + walker)
//   cache.odin              → write_cache, read_cache_if_fresh, invalidate_cache
//   list_files.odin         → list_files (single-dir listing)
//   search.odin             → search_files, search_files_to_file (live search)
//   index.odin              → build_index, index_meta, search_index_to_file, group_by_day (C file-backed)
//   cleaner.odin            → find_large_files, find_duplicates
//   organizer.odin          → plan_organize, apply_organize_file
//   stats_db.odin           → stats_db_record (SQLite, best-effort)
//
// Android 10 note: See fs_android.odin — all file I/O is bionic-safe.
// =============================================================================

package storage
