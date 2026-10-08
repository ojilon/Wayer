# 22 — `FileIndexer`: paths only (the Java walk is DELETED on purpose)

## Goal
Understand why this file is tiny now, and what replaced the walk.

## Touches
- `app/src/main/java/com/example/wayer/storage/FileIndexer.java:16-30`
- `docs/BRIDGE_PLAN.md:207-226` (Step 7), `bridge/NativeEngine.java:52-67`
- `native/storage/src/index.cpp`, `include/wayer/storage/index.hpp` (`BUILD_INDEX/INDEX_META/SEARCH_INDEX`)

## How it works today
- Old Java tree-walk cache deleted. `FileIndexer` keeps ONLY `DEFAULT_ROOT` + `getDefaultSavePath()` (Download dir or external root or `/storage/emulated/0`).
- Whole-storage indexing = native `BUILD_INDEX` into `cache/index/files.json`; `INDEX_META` guards reads; Transfer + global search read the FILE.
- Files tab keeps SCOPED live search (`SEARCH_FILES` on current folder) — index is stale by design, explorer must show just-created files.

## Guided tasks
1. Read `FileIndexer.java` + BRIDGE_PLAN Step 7. Explain to yourself: which search uses index vs live walk, and why.
2. Trace `buildIndexAsync` -> JNI 15 -> `index.cpp` -> `cache/index/files.json` -> `indexMetaAsync` guard.
3. Improvement: `getDefaultSavePath()` fallback chain — add scoped-storage `MediaStore.Downloads` check? Or per-user subfolder `Wayer/`? Implement + handle `mkdirs` failure as Result.
4. Document freshness contract in `FileIndexer` header: "index search may miss files added after last refresh; scoped search never does."

## Stretch
- Add `needsRebuild(meta, maxAge)` helper: compare `modified_unix` vs now. Use from Transfer search.

## Verify
- [ ] Airplane test: index search works offline; new file missed until refresh; scoped search finds it immediately.
