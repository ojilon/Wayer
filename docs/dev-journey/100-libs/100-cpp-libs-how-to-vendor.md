# 100 — Vendoring C++ libs (the safe pattern: gitignored + fail-fast)

## Goal
Add libs without bloating git or drowning in third-party warnings.

## Touches
- `native/third_party/` (+ `README.md`), `native/CMakeLists.txt:21-48` (fail-fast + `wayer_json`/`wayer_sqlite3` pattern), `.gitignore`
- `docs/BRIDGE_PLAN.md:64-133` (Step 0), `native/cmake/CompilerFlags.cmake`

## How it works today
- `third_party/{json,sqlite}/` gitignored locally; CMake `FATAL_ERROR` if missing (fail fast at configure, not deep in build).
- `wayer_json` INTERFACE (header-only, include dir only); `wayer_sqlite3` STATIC (compiled once, deliberately NOT linked to `project_warnings` — 9MB C file would drown us).
- Modules opt in: `target_link_libraries(... PRIVATE wayer_json)` only where needed.

## Guided tasks
1. Read `third_party/README.md` + `.gitignore` entries. Confirm `json.hpp` (~900KB, `#pragma once`, `NLOHMANN_JSON_VERSION_MAJOR`) + `sqlite3.{h,c}` present.
2. Dry-run vendoring a NEW lib (xxHash, see 31/104): download release zip, keep ONLY `xxhash.h/.c` (+ `LICENSE`), layout `third_party/xxhash/{xxhash.h,xxhash.c,LICENSE,README_WAYER.md (version+URL+sha)}`, CMake `wayer_xxhash` STATIC mirroring sqlite (no warnings lib).
3. License check per lib (MIT/BSD/public-domain OK; GPL/LGPL needs lawyer-grade care on Play Store — document + avoid). Record in `README_WAYER.md`.
4. CI: ensure fresh-runner install steps (script in `third_party/README.md`) so PR builds don't "work on my machine" only.

## Stretch
- Version pin file: `third_party/VERSIONS.txt` (lib, version, URL, sha256). Verify script `sha256sum -c`? Cheap, high trust.

## Verify
- [ ] Fresh clone + scripted vendor + `assembleDebug` green; warnings only from OUR code.
