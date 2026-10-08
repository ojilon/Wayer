# 81 — Zig via CMake: the build-system entry (smallest safe slice)

## Goal
Your ask: "starting from the side of the cmake build system." Wire Zig WITHOUT disturbing the APK.

## Touches
- `native/CMakeLists.txt:50-56` (`add_subdirectory(...)`), `native/cmake/CompilerFlags.cmake`
- `app/build.gradle:43-48,88-93` (`externalNativeBuild.cmake.path` stays `native/CMakeLists.txt`, artifact stays `libwayer_engine.so`)
- New: `native/zig/` (proposed: `build.zig`, `src/`, `CMakeLists.txt` shim)

## How CMake works today
Root orchestrates `core/storage/documents/transfer/media/preview/jni`; third_party `wayer_json` (INTERFACE) + `wayer_sqlite3` (STATIC); `wayer_native_modules` alias; Gradle points at root; artifact name fixed.

## Guided tasks (in order — stop if any step fights)
1. **Host-only first (no Gradle):** `native/zig/build.zig` building a `zig test` binary for pure logic (e.g. extension-category table test reading a SHARED `categories.json`?). `zig build test` green on Windows/Linux. No CMake yet.
2. **CMake shim (opt-in):** `native/zig/CMakeLists.txt` with `find_program(ZIG zig)`; if NOTFOUND -> `message(STATUS "zig not found — skipping zig checks")`, NEVER `FATAL_ERROR`. Adds `add_custom_target(wayer_zig_checks COMMAND zig build test ...)`. Root `add_subdirectory(zig)` guarded by option `WAYER_ENABLE_ZIG (default ON but non-fatal)`.
3. **Gradle untouched:** verify `assembleDebug` works WITH and WITHOUT zig installed (uninstall/rename zig, rebuild — must still pass). CI: two jobs (with-zig / without-zig).
4. **Share ONE table:** extract `categories.json` (ext->category) committed; BOTH C++ `extension_map.cpp` test AND Zig test read it. Proves cross-lang truth without sharing code yet.

## Stretch
- `zig cc` as host compiler for `json_util`/`text` unit tests? Only if step 1 felt easy.

## Verify
- [ ] `assembleDebug` green with + without zig; `zig build test` green; no artifact rename.
