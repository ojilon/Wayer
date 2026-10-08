# 01 — Repo map: where everything lives

## Goal
Never get lost: know which folder owns which behavior.

## Touches
- `README.md`, `native/MODULES.md`, `docs/BRIDGE_PLAN.md`, `docs/TRANSFER_CLEANER_PLAN.md`
- `app/src/main/java/com/example/wayer/` (`bridge/`, `core/`, `ui/`, `storage/`, `transfer/`, `network/`)
- `native/` (`core/`, `storage/`, `documents/`, `transfer/`, `media/`, `preview/`, `jni/`, `third_party/`)
- `app/src/main/res/layout/`, `app/build.gradle`, `native/CMakeLists.txt`

## How it works today
- **Java+XML** = UI, navigation, sockets (`network/NetworkManager.java`).
- **`bridge/`** = single doorway to native: `NativeEngine.java` (ACTION ids),
  `Bridge.java` (single-thread executor), `PathRegistry.java`, `FileLeases.java`,
  `PathCache.java`, `NativeCache.java`, `AppDirs.java`.
- **C++** = compute into files under private app home; JNI carries only status+path.
- Layouts in `res/layout/` map 1:1 to Fragments (`fragment_files.xml` <-> `FilesFragment.java`).

## Guided tasks
1. Open `native/MODULES.md` dependency graph. Draw it on paper: core <- storage <- documents/transfer/media; preview core-only; jni links all.
2. List all `ACTION_*` in `bridge/NativeEngine.java:5-24`. For each, find its `case` in `native/jni/wayer_engine.cpp`.
3. Open `app/src/main/res/layout/` — match each `fragment_*.xml` to its `ui/*Fragment.java`.
4. Find where APK lands: `app/build/outputs/apk/debug/app-debug.apk`.

## Stretch
- Run `collect_context.py` (repo root) and skim `context.txt` — see what agents see.

## Verify
- [ ] You can point at any feature and name its Java helper + native file + layout.
