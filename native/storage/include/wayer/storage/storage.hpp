#pragma once
// Public facade for the storage module.
// During migration, implementations remain in legacy headers under native/storage/*.hpp
// Prefer new code include this file and call namespaced APIs.

namespace wayer::storage {

int storage_module_anchor();

// Existing APIs (still declared in legacy headers until moved):
//   list_files, get_storage_stats, search_files, find_large_files,
//   find_duplicates, plan_organize, apply_organize,
//   write_cache, read_cache_if_fresh

} // namespace wayer::storage
