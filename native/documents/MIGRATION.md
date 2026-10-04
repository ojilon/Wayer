# documents — migration & improvements

**CMake target:** `wayer_documents`  
**Depends on:** `wayer_core`, `wayer_storage` (for paths / listing as needed)

## Migrate

| Legacy | Destination |
|--------|-------------|
| `document_engine.cpp` | `src/document_engine.cpp` |
| `document_engine.hpp` | `include/wayer/documents/documents.hpp` (or `document_engine.hpp`) |

Update `documents/CMakeLists.txt` source list; remove `../` include once includes are `<wayer/documents/...>`.\n
## Improvements

- [ ] Keep filtering here; heavy **rendering/editing** later may wrap third_party engines
- [ ] Prefer returning cache file paths for large filtered lists
- [ ] No JNI in this module

## Agent checklist

- [x] Legacy files moved; JNI includes updated
- [x] Links only core + storage
