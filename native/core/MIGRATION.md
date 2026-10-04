# core — migration & improvements

**CMake target:** `wayer_core`  
**Depends on:** nothing domain-specific  
**Used by:** storage, documents, transfer, media, jni

## Purpose

Foundation only: types, app paths (cache/temp/logs), JSON helpers, logging facade.
No filesystem domain logic, no transfer, no JNI.

## Migrate from legacy

| Legacy path | Action |
|-------------|--------|
| `native/utils/json_util.hpp` | Copy API into `include/wayer/core/json_util.hpp` (header-only is fine). Update all includes. Delete `utils/` when unused. |
| *(new)* `src/paths.cpp` | Implement `AppPaths::from_root`, `set_app_paths`, `app_paths` declared in `paths.hpp`. Create `cache/`, `temp/`, `logs/` under root. |
| *(new)* `include/wayer/core/logging.hpp` + `src/logging.cpp` | Thin wrapper over `__android_log_print` + optional file under `app_paths().logs`. |

## CMake steps

1. Add real `.cpp` files to `core/CMakeLists.txt`.
2. Remove `src/core_placeholder.cpp` when no longer needed for an empty lib.
3. Ensure dependents `target_link_libraries(... PUBLIC wayer_core)` if they need headers.

## Improvements to implement

- [x] Java calls a new JNI init action that passes `context.getFilesDir()` (or `.../wayer`) once
  (`MainActivity.onCreate` → `NativeEngine.initAppPathsAsync`).
- [x] All cache file paths go through `wayer::core::app_paths()`, not hard-coded strings in storage
  (index paths do; `ACTION_GET_CACHED_STATS` keeps an explicit path for backward compat).
- [x] Prefer `std::string_view`, `std::filesystem` in new code (C++23 already enabled).
- [ ] Do not parse complex JSON here until a library is chosen (see `storage/flags.md`).

## Agent checklist

- [x] `json_util` fully moved; zero includes of `utils/json_util.hpp`
- [x] `AppPaths` implemented and tested from JNI
- [x] `core_placeholder.cpp` removed or reduced
- [x] `native/MODULES.md` dependency graph still valid
