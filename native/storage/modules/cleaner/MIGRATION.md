# storage/modules/cleaner

**Target:** `wayer_storage_cleaner` (STATIC)

## Migrate — done

| Legacy | Destination |
|--------|-------------|
| `duplicate_finder.cpp/.hpp` | `src/` + `include/wayer/storage/cleaner.hpp` |
| `large_files.cpp/.hpp` | same module |

CMake is STATIC; those files are not in the parent `wayer_storage` sources.

## Improvements

- Safer delete plans (dry-run JSON file under cache)
- Grouped duplicate resolution payloads (may need real JSON parser)
