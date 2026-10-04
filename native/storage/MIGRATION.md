# storage — migration & improvements

**CMake target:** `wayer_storage`  
**Depends on:** `wayer_core`  
**Optional submodules:** `modules/search`, `modules/cleaner`, `modules/organizer`

## Legacy inventory (move into include/ + src/)

| Legacy file | Destination | Notes |
|-------------|-------------|--------|
| `dir_walker.hpp` | `include/wayer/storage/walker.hpp` (+ .cpp if split) | Shared walk primitive |
| `safety_rules.hpp` | `include/wayer/storage/safety.hpp` | |
| `extension_map.hpp` | `include/wayer/storage/extension_map.hpp` | |
| `list_files.cpp/.hpp` | `src/` + `include/wayer/storage/` | |
| `analyse_storage_space.cpp/.hpp` | same | Pass device capacity from Java (see flags.md) |
| `storage_cache.cpp/.hpp` | same | Tie paths to `wayer::core::app_paths()` |
| `file_search.cpp/.hpp` | **modules/search** when split | Until then keep in parent target |
| `duplicate_finder.cpp/.hpp` | **modules/cleaner** | |
| `large_files.cpp/.hpp` | **modules/cleaner** or parent | |
| `file_organizer.cpp/.hpp` | **modules/organizer** | |
| `flags.md` | keep in storage/ | open decisions |

Also update includes in `jni` / `wayer_engine.cpp` from `"storage/foo.hpp"` to `<wayer/storage/foo.hpp>` after moves.

## CMake steps

1. Move one `.cpp` at a time into `src/`; switch path in `storage/CMakeLists.txt`.
2. When splitting search/cleaner/organizer: move sources into submodule `src/`, list them in submodule `CMakeLists.txt`, remove from parent list.
3. Drop `${CMAKE_CURRENT_SOURCE_DIR}/..` from include dirs when no legacy `"storage/..."` includes remain.

## Improvements (product)

- [x] **File-backed index:** `BUILD_INDEX` writes under `app_paths().cache/index/`;
  `INDEX_META` returns `{path, bytes, modified_unix}` and `SEARCH_INDEX` searches
  the file (see `include/wayer/storage/index.hpp`). JNI returns paths + metadata
  only; Java reads the file for the full listing.
- [x] Invalidate cache after organize/delete: `invalidate_cache` (action 16) plus
  Java `NativeCache.invalidateStatsSnapshot`, called from delete confirmations and
  `OrganizeHelper.apply(Context, ...)`.
- [x] Wire real device capacity from Java into `get_storage_stats`
  (`StorageCapacity.queryDeviceBytes` → `root|bytes`; 4th field on cached-stats).
- [ ] Consider nlohmann/json when pipe-delimited payloads become nested.

## Agent checklist

- [x] All storage sources compile only via `wayer_storage` (no duplicate listing in jni)
- [x] Public headers under `include/wayer/storage/`
- [x] Submodules own their .cpp as STATIC libs (search, cleaner, organizer)
- [x] App cache root comes from core AppPaths (`index.*`; cached-stats keeps an
  explicit path for backward compat)
