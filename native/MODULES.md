# Native modular layout (agent guide)

Branch: `refactor/native-modules` (off `main`).

This tree keeps everything under **`native/`** (not repo-root `backend/`).
Modules are independent sibling roots with their own `CMakeLists.txt` and public headers.

## Target layout

```text
native/
├── CMakeLists.txt              # orchestrates modules → libwayer_engine.so
├── MODULES.md                  # this file
├── cmake/
│   └── CompilerFlags.cmake
├── core/                       # wayer_core — foundation only
│   ├── CMakeLists.txt
│   ├── MIGRATION.md
│   ├── include/wayer/core/
│   └── src/
├── storage/                    # wayer_storage (+ optional submodules)
│   ├── CMakeLists.txt
│   ├── MIGRATION.md
│   ├── include/wayer/storage/
│   ├── src/                    # destination for migrated .cpp
│   ├── modules/
│   │   ├── search/
│   │   ├── cleaner/
│   │   └── organizer/
│   └── (legacy *.cpp / *.hpp until moved — see MIGRATION.md)
├── documents/                  # wayer_documents
│   ├── CMakeLists.txt
│   ├── MIGRATION.md
│   ├── include/wayer/documents/
│   └── src/
├── transfer/                   # wayer_transfer
│   ├── CMakeLists.txt
│   ├── MIGRATION.md
│   ├── include/wayer/transfer/
│   └── src/
├── media/                      # wayer_media (placeholder for later)
│   ├── CMakeLists.txt
│   ├── MIGRATION.md
│   ├── include/wayer/media/
│   └── src/
├── preview/                    # wayer_preview (read-only text preview)
│   ├── CMakeLists.txt
│   ├── MIGRATION.md
│   ├── include/wayer/preview/
│   └── src/
├── jni/                        # SHARED lib boundary only
│   ├── CMakeLists.txt
│   ├── MIGRATION.md
│   └── wayer_engine.cpp        # move from native/wayer_engine.cpp
├── utils/                      # LEGACY — migrate into core/, then delete
└── third_party/
```

## Dependency graph (must stay acyclic)

```text
core
  ↑
storage  ←── documents
  ↑      ←── transfer
  ↑      ←── media (later)
  ↑
preview (core only — read-only text for the in-app viewer)
jni links: core, storage, documents, transfer, media, preview
```

Rules:

1. No `JNIEnv` outside `jni/`.
2. Domain modules depend only downward (`PUBLIC`/`PRIVATE` link as documented per module).
3. Large results → files under app cache (see `core` AppPaths); JNI returns paths + metadata.
4. Do not rename `native/` to `backend/` unless Gradle `externalNativeBuild` is updated in the same change.

## C++ style for this tree (keep it beginner-readable)

- Plain structs + free functions; no `class`, no inheritance, no virtuals.
- Headers declare, `.cpp` files define — no `inline` functions or globals in headers.
- Plain `for`/`while`/`if` over clever algorithms; one shared helper beats five
  local lambdas (see `core::ascii_lower`).
- Name every conversion: `static_cast` for narrowing is honest and required;
  `reinterpret_cast` appears only where an OS API forces it (sockets).
- No macros for logging — use `wayer::core::log`. No `using namespace`.
- `std::string_view` at API edges, `std::filesystem`, `std::error_code`
  (never exceptions) — modern STL/RAII, nothing exotic.

## Build status

- Modular CMake targets own their sources (`include/` + `src/`).
- Legacy flat sources (`storage/*.cpp`, root `wayer_engine.cpp`, `utils/`) are removed.
- JNI resolves everything via `<wayer/...>` through module targets (no parent-dir include hacks).
- Storage submodules (`search`, `cleaner`, `organizer`) are STATIC libs owning their `.cpp`.
- File-backed index is complete: `BUILD_INDEX` / `INDEX_META` / `SEARCH_INDEX`
  (`storage/index.hpp`); Java passes app files dir once and real device capacity
  per stats call; caches are invalidated after mutations.
- `wayer_preview` serves capped read-only text previews to `DocumentActivity`
  (action 19); the Internals bottom-nav destination browses the private home.

## Ordered migration for agents

1. Read this file + `core/MIGRATION.md`.
2. Finish **core** (json_util, paths, logging stubs). — done
3. **storage** (walk, list, stats, cache) — largest; then split search/cleaner/organizer if needed. — done
4. **documents** and **transfer**. — done
5. Move `wayer_engine.cpp` → `jni/` and drop legacy root `wayer_engine.cpp`. — done
6. Delete empty legacy paths; ensure `#include <wayer/...>` works; remove parent-dir include hacks. — done
7. Java: pass app files dir into native once; use file-backed index (see storage MIGRATION). — done

Remaining open items: nlohmann/json if payloads need nesting (flags.md),
media metadata extraction, transfer transports behind the same facade.

## Gradle

`app` already points `externalNativeBuild.cmake.path` at `native/CMakeLists.txt`.
No path change required as long as the final artifact remains `libwayer_engine.so`.
