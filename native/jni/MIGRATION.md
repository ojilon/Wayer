# jni — migration & improvements

**CMake target:** `wayer_engine` (SHARED → `libwayer_engine.so`)  
**Depends on:** all domain static libs  
**Rule:** only place allowed to include `<jni.h>` / use `JNIEnv`

## Migrate

| Legacy | Destination |
|--------|-------------|
| `native/wayer_engine.cpp` | `native/jni/wayer_engine.cpp` |

`jni/CMakeLists.txt` already falls back to `../wayer_engine.cpp` until the file is moved.

After move:

1. Update includes to `<wayer/storage/...>`, `<wayer/core/paths.hpp>`, etc.
2. Confirm `System.loadLibrary("wayer_engine")` still matches (no rename).
3. Delete legacy root copy.

## Improvements

- [ ] Init path: accept app files dir; call `wayer::core::set_app_paths`
- [ ] New actions: `BUILD_INDEX` / `INDEX_META` returning **paths + metadata**, not huge JSON
- [ ] Keep single `processAction(id, payload)` entry (see FUTURE_JNI_AND_CPP23.md)
- [ ] No domain logic growth in this file — only route to modules

## Agent checklist

- [ ] `wayer_engine.cpp` lives under `jni/`
- [ ] No other `.cpp` in the tree includes `jni.h`
- [ ] Android build still produces `libwayer_engine.so`
