# storage/modules/cleaner

**Target:** `wayer_storage_cleaner` (currently INTERFACE)

## Migrate

| Legacy | Destination |
|--------|-------------|
| `duplicate_finder.cpp/.hpp` | `src/` + `include/wayer/storage/cleaner.hpp` (or dedicated headers) |
| `large_files.cpp/.hpp` | same module |

Switch CMake from INTERFACE → STATIC; remove those files from parent `wayer_storage` sources.

## Improvements

- Safer delete plans (dry-run JSON file under cache)
- Grouped duplicate resolution payloads (may need real JSON parser)
