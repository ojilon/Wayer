# 71 — StorageFragment: stats snapshot + category bars (refresh forces recompute)

## Goal
Numbers users trust: same snapshot Home+Storage, refresh = truth.

## Touches
- `app/src/main/java/com/example/wayer/ui/StorageFragment.java`, `res/layout/fragment_storage.xml`
- `storage/StorageController.java`, `storage/StorageItem.java`, `bridge/Stats.java`, `bridge/NativeCache.java`
- Native: `storage/src/stats_json.cpp`, `stats_db.cpp`, `analyse_storage_space.cpp`

## How it works today
Stats document via JSON lib with per-folder detail, SQLite history row best-effort, file-backed action 13 (action 7 retired). Home+Storage share `bridge/Stats`. Refresh forces recompute; caches invalidated after mutations.

## Guided tasks
1. Read a real `snapshot.json` (Internals). Map each field to a UI element (summary numbers, category bars, folders list?). Note any field shown NOWHERE (candidate for 35 rollup).
2. Bars: audit custom bar View (colors? night parity? a11y labels?). Fix night mismatch if any (see D3 night parity precedent).
3. Refresh: confirm it takes lease, shows spinner, keeps OLD numbers on failure (never blank). Fix if it blanks.
4. History sparkline (cheap, per CLEANER_IDEAS trend): read `stats.db` rows, draw used/free over time (custom View, no lib). v1: 30 points, text fallback if <2 rows.

## Stretch
- Per-folder drill: tap bar segment -> 35 rollup tab filtered. Wire navigation.

## Verify
- [ ] Numbers match snapshot file bytes; refresh-while-search safe; night correct.
