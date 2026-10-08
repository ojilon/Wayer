# 91 — Indexing design: JSON file today, SQLite/LSM tomorrow? (measure first)

## Goal
Decide the index future with data, not hype.

## Touches
- Today: `native/storage/src/index.cpp`, `include/wayer/storage/index.hpp` (`BUILD_INDEX` -> `cache/index/files.json`, `INDEX_META`, `SEARCH_INDEX`)
- Readers: Transfer Search (67), global search (28); freshness contract (22)
- History: `stats.db` (101) as the SQLite pattern to copy IF needed

## How it works today
Walk once -> spill listing to ONE JSON file; meta guards reads; search scans file. Simple, debuggable in Internals, offline-friendly.

## Read (then come back)
- Kleppmann DDIA ch3 (SSTables/LSM) + ch4 (encodings) — OR SQLite docs: `CREATE INDEX`, WAL mode, `FTS5`.
- SQLite `EXPLAIN QUERY PLAN` on a toy `files(path,size,mtime)` table (100k synthetic rows — generate with 84 tool).

## Guided tasks
1. Measure TODAY: index build ms + file bytes + search ms for 10k/50k/100k files (synthetic tree on host or large device dir). Record in PR/table.
2. Thresholds: if build <5s AND search <300ms at 100k — STAY JSON (document + stop). If over — prototype SQLite `files` table + `LIKE`/`FTS5` behind flag, same JNI contract (`SEARCH_INDEX` payload unchanged, impl swaps).
3. Freshness: delta vs rebuild? Measure rebuild first (likely fine). Delta only if rebuild proven slow on YOUR device.
4. Concurrency: leases (26) already serialize; SQLite WAL vs rollback — pick + document (WAL = readers don't block writer).

## Stretch
- Sharding by root? NO until single-file measured slow. Park with number.

## Verify
- [ ] Numbers table committed; stay-or-migrate decision recorded with threshold.
