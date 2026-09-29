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
jni links: core, storage, documents, transfer, media
```

Rules:

1. No `JNIEnv` outside `jni/`.
2. Domain modules depend only downward (`PUBLIC`/`PRIVATE` link as documented per module).
3. Large results → files under app cache (see `core` AppPaths); JNI returns paths + metadata.
4. Do not rename `native/` to `backend/` unless Gradle `externalNativeBuild` is updated in the same change.

## Build status on this branch

- Modular CMake targets exist and own their sources (`include/` + `src/`).
- Legacy flat sources (`storage/*.cpp`, root `wayer_engine.cpp`, `utils/`) are removed.
- JNI resolves everything via `<wayer/...>` through module targets (no parent-dir include hacks).

## Ordered migration for agents

1. Read this file + `core/MIGRATION.md`.
2. Finish **core** (json_util, paths, logging stubs).
3. **storage** (walk, list, stats, cache) — largest; then split search/cleaner/organizer if needed.
4. **documents** and **transfer**.
5. Move `wayer_engine.cpp` → `jni/` and drop legacy root `wayer_engine.cpp`.
6. Delete empty legacy paths; ensure `#include <wayer/...>` works; remove parent-dir include hacks.
7. Java: pass app files dir into native once; use file-backed index (see storage MIGRATION).

## Gradle

`app` already points `externalNativeBuild.cmake.path` at `native/CMakeLists.txt`.
No path change required as long as the final artifact remains `libwayer_engine.so`.
