# 67 — Offline index search for Transfer (airplane-test honest)

## Goal
Upload search works fully offline from the shared index file — with honest staleness.

## Touches
- `NativeEngine.searchIndexAsync:63` + `buildIndexAsync:52` + `indexMetaAsync:58`
- Native `storage/index.hpp` (`BUILD_INDEX/INDEX_META/SEARCH_INDEX`), `modules/search/file_search.cpp`
- `FileIndexer.java` freshness contract (22), Transfer Search tab

## How it works today
Meta-gated rebuild: missing/stale index -> build first, then search. Java walk deleted. Files scoped search separate (fresh).

## Guided tasks
1. Airplane test now: enable airplane, search Transfer. Works? Time it. Note `modified_unix` in Internals.
2. Staleness UX: "Index from Tue 08:12 · 12,400 files — [Refresh]" header on Search tab. After refresh, `modified_unix` updates. Implement header if missing.
3. Miss case: add a file, search BEFORE refresh (miss — expected), AFTER refresh (hit). Teach this in Guide tab copy ("upload search finds files added before last refresh").
4. Perf: `maxResults` cap + debounced typing (see 28). Confirm single-retry/already-running on rapid type.

## Stretch
- Delta index? OUT — full rebuild is fine until measured slow (>5s on 100k files). Record your timing first.

## Verify
- [ ] Offline search works; header shows age; Guide documents miss-until-refresh.
