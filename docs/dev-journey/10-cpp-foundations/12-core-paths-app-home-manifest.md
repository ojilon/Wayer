# 12 — `core::AppPaths` + `paths.json` manifest (private home)

## Goal
Understand why native never writes to shared storage directly.

## Touches
- `native/core/include/wayer/core/paths.hpp`, `native/core/src/paths.cpp`
- Java: `bridge/AppDirs.java`, `bridge/PathRegistry.java`, `NativeEngine.initAppPathsAsync:38`
- Docs: `docs/BRIDGE_PLAN.md:42-50`, `docs/STORAGE_AND_TRANSFER.md`
- Device: Internals tab -> `files/wayer/paths.json`, `cache/`, `modules/*/`, `logs/`

## How it works today
- Java passes private root ONCE (`ACTION_INIT_APP_PATHS=14`); native writes manifest
  (`paths.json`) + per-module scratch dirs (`modules/search/`, `modules/cleaner/`, ...).
- Java `PathRegistry.moduleDir(ctx,"organizer")` reads manifest; C++ assumes out-path
  parent exists but still fails cleanly with `{"status":"error","reason":"..."}`.
- Private internals stay in `getFilesDir()`; only explicit user files go to shared storage.

## Guided tasks
1. On device, open Internals, copy the `paths.json` content. Map each key to a `moduleDir()` call.
2. Trace `initAppPathsAsync` -> JNI `INIT_APP_PATHS` -> `paths.cpp` -> manifest write -> `PathRegistry.update`.
3. Improvement: add a `paths.json` version field + Java migration check (v1->v2). Draft the schema.
4. Safety: list dirs C++ must NEVER write (shared root, `Android/data`). Confirm `safety.hpp` covers them.

## Stretch
- Design log rotation: `logs/` capped at N MB, oldest-first delete. Where: `paths.cpp` or new `log_rotate.cpp`?

## Verify
- [ ] Fresh install still creates manifest; Internals shows it; no path hardcoding in Java.
