# transfer — migration & improvements

**CMake target:** `wayer_transfer`  
**Depends on:** `wayer_core`, `wayer_storage` (paths, staging under temp/)

## Migrate

| Legacy | Destination |
|--------|-------------|
| `transfer_engine.cpp` | `src/transfer_engine.cpp` |
| `transfer_engine.hpp` | `include/wayer/transfer/transfer.hpp` |

## Improvements

- [ ] Use `app_paths().temp` for staging incoming/outgoing files
- [ ] Hash/verify helpers in C++; keep discovery/UI in Java until protocol stabilizes
- [ ] Future: LAN/internet transports as additional .cpp behind same facade
- [ ] Do not depend on documents/media (keep graph acyclic)

## Agent checklist

- [ ] Sources under src/ + public include
- [ ] JNI only calls into this module from `jni/`
