# Native modular layout (agent guide) — updated Oct 2025 for Odin

Branch: `arena/e58556e6-wayer` (off `main`) · Odin `dev-2025-10` · target Android 10 (API 29).

This tree now has **two languages**: C/C++ (C++23 + C11) and **Odin** (`*.odin`). Odin is the primary new code; C++ remains linking for the transition. See `docs/NATIVE_OVERVIEW.md` for the full October 2025 sweep (syntax fixes, bionic wrappers).

This tree keeps everything under **`native/`** (not repo-root `backend/`).
Modules are independent sibling roots with their own `CMakeLists.txt` and public headers.

## Target layout

```text
native/
├── CMakeLists.txt              # orchestrates C++ modules → Odin archive → libwayer_engine.so
├── MODULES.md                  # this file
├── cmake/CompilerFlags.cmake
├── odin/
│   ├── build_odin.cmake        # packs Odin .o → libwayer_core_odin.a via llvm-ar
│   └── wayer_core.odin         # action router + C ABI exports (only package CMake builds)
├── core/                       # wayer_core — foundation only (Odin + C)
│   ├── include/wayer/core/     # android_fs.h (bionic allowlist), json_util.hpp, paths.hpp, logging.hpp
│   ├── src/
│   │   ├── *.odin              # core_heart package: json_util, paths, logging, text (+ header comments)
│   │   ├── *.cpp/.c            # C++ impl + android_fs.c (bionic-safe FS)
│   │   └── android_fs.c
│   └── CMakeLists.txt
├── storage/                    # wayer_storage — largest (Odin + C)
│   ├── include/wayer/storage/
│   ├── src/
│   │   ├── *.odin              # storage package: fs_android (central C bridge), analyser, walker, cache, search, cleaner, organizer, index, stats_db/json
│   │   ├── *.c/.cpp            # index_c.c (file-backed index), dir_walk_android.c, collect_data.c, etc.
│   │   └── index_c.c
│   └── modules/search|cleaner|organizer
├── documents/                  # wayer_documents (Odin + C helpers)
├── transfer/                   # wayer_transfer (Odin + transfer_shim.c)
├── media/                      # wayer_media (Odin stub, future thumbs)
├── preview/                    # wayer_preview (Odin capped text preview)
├── jni/                        # SHARED lib boundary only — wayer_engine.c (thin JNI router, no logic)
├── shim/                       # odin_bionic_shim.h (contract) + wayer_shim.cpp (legacy C++ exports, being replaced by Odin)
├── third_party/                # nlohmann/json + SQLite (gitignored)
└── odin/                       # Odin package root (see native/odin/wayer_core.odin doc)
```

## Dependency graph (must stay acyclic) — Oct 2025 adds Odin packages mirroring C++

```text
core  (core_heart in Odin)
  ↑
storage (storage in Odin)  ←── documents (documents)
  ↑                        ←── transfer  (transfer)
  ↑                        ←── media     (media, leaf)
  ↑
preview (preview — core + storage read-only, not storage write)
jni links: wayer_core_odin (static archive from Odin) + all C++ modules + C wrappers
```

Odin packages are siblings of their C++ twins (`native/<module>/src/*.odin` imports `../../core/src` relatively). The JNI `.so` links the Odin archive + the C/C++ modules (see `native/CMakeLists.txt` Odin section).

Rules:

1. No `JNIEnv` outside `jni/`.
2. Domain modules depend only downward (`PUBLIC`/`PRIVATE` link as documented per module).
3. Large results → files under app cache (see `core` AppPaths); JNI returns paths + metadata.
4. Do not rename `native/` to `backend/` unless Gradle `externalNativeBuild` is updated in the same change.

## Style for this tree — C++ + Odin (keep it beginner-readable)

### C++
- Plain structs + free functions; no `class`, no inheritance, no virtuals.
- Headers declare, `.cpp` files define — no `inline` functions or globals in headers.
- Plain `for`/`while`/`if` over clever algorithms; one shared helper beats five local lambdas (see `core::ascii_lower`).
- Name every conversion: `static_cast` for narrowing is honest and required; `reinterpret_cast` only where OS API forces it (sockets).
- No macros for logging — use `wayer::core::log`. No `using namespace`.
- `std::string_view` at API edges, `std::filesystem`, `std::error_code` (never exceptions) — modern STL/RAII, nothing exotic.

### Odin (Oct 2025)
- `package` per module, one `.odin` per concern (mirrors C++ split); header comment block in every file documents purpose + bionic contract.
- No `core:os` for filesystem — use `fs_android.odin` C wrappers (`stat_c`, `walk_files_c`, etc.). See `native/shim/odin_bionic_shim.h` allowlist.
- `ODIN_OS == .Android` enum, `foreign import "system:c"` + `@(default_calling_convention="c")`, explicit `context.temp_allocator` + `defer free_all` per JNI call.
- File-backed replies: JSON spilled to `cache/` file, JNI returns `{status, path}`; Java reads via `PathCache`.
- `when ODIN_OS == .Android` for log vs host branches; no `using` statement; `make(map[...])` not `{}` literals.

## Build status — Oct 2025 sweep complete

- Modular CMake targets own their sources (`include/` + `src/`); JNI resolves via `<wayer/...>`.
- Legacy flat sources removed; storage submodules (`search`, `cleaner`, `organizer`) are `STATIC` libs.
- File-backed index: `BUILD_INDEX` / `INDEX_META` / `SEARCH_INDEX` / `GROUP_INDEX_BY_DAY` (`index_c.c` + Odin bridge in `storage/index.odin`); Java passes app files dir once.
- **Odin sweep**: all `native/**/*.odin` corrected for `dev-2025-10` syntax (see `docs/NATIVE_OVERVIEW.md` §2-3); `wayer_core.odin` is the only package CMake builds, re-exports `wayer_*` C ABI (replacing `shim/wayer_shim.cpp` progressively); `android_fs.c` is the bionic abstraction for every Odin file op.
- `wayer_preview` capped text preview (action 19); Internals destination browses private home.
- `wayer_media` stub anchored so `wayer_media` target is never empty.

## Ordered migration — updated for Odin (agents)

1. Read this file + `core/MIGRATION.md` + `docs/NATIVE_OVERVIEW.md`.
2. **core** — `json_util`, `paths`, `logging`, `text` ported to Odin (`core_heart` package) with C wrappers. — done Oct 2025
3. **storage** — `walk`, `list`, `stats`, `cache`, `search`, `cleaner`, `organizer`, `index` ported (see §2-3). — done Oct 2025
4. **documents** and **transfer** — walk/filter + socket stub ported. — done Oct 2025
5. Move `wayer_engine.cpp` → `jni/` — done; `wayer_engine.c` is now a thin C router to `wayer_route_action` in Odin.
6. Legacy paths deleted; `#include <wayer/...>` works via module targets (no parent-dir hacks). — done
7. Java passes `filesDir` once (`ACTION_INIT_APP_PATHS`); index is file-backed (`BUILD_INDEX` → `SEARCH_INDEX` → file). — done
8. **Odin October 2025 sweep** — all `*.odin` corrected for `dev-2025-10` + Android 10 bionic allowlist (see `docs/NATIVE_OVERVIEW.md` §2). — done this branch

Remaining open items: media metadata extraction (ExoPlayer on Java side; native thumb paths under `cache/`), transfer full transport behind the facade, nlohmann/json for deeply nested payloads (flags.md).

## Gradle

`app` already points `externalNativeBuild.cmake.path` at `native/CMakeLists.txt`.
No path change required as long as the final artifact remains `libwayer_engine.so`.
