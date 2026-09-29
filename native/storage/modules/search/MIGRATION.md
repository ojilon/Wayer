# storage/modules/search

**Target:** `wayer_storage_search` (currently INTERFACE)

## Migrate

1. Move `native/storage/file_search.cpp` → `modules/search/src/file_search.cpp`
2. Move API to `include/wayer/storage/search.hpp` (namespace `wayer::storage::search` or keep `wayer::storage` for less churn)
3. Change this `CMakeLists.txt` from INTERFACE to STATIC and list the `.cpp`
4. Remove `file_search.cpp` from parent `storage/CMakeLists.txt`
5. Update JNI includes / calls

## Improvements

- Search over **index files** under cache (not full tree walk every time)
- Return path to result file when hit lists are large
