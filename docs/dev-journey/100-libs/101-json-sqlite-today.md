# 101 — nlohmann/json + SQLite today (where each owns what)

## Goal
Stop guessing "json or sqlite?" — own the split.

## Touches
- JSON: `file_organizer.cpp:9,165` (plan/report), stats snapshot (`stats_json.cpp`), `third_party/json/include/nlohmann/json.hpp`
- SQLite: `storage/src/stats_db.cpp`, `include/wayer/storage/stats_db.hpp`, `cache/stats/stats.db` (history rows)
- Future users: transfer history (66), usage opens (41), trash manifest (39 — JSON file is fine, don't over-sqlite)

## How it works today
- JSON doc where payloads nest/dynamic (stats w/ per-folder, organize moves). Hand-`format` stays where flat (11).
- SQLite for HISTORY (stats rows over time; future transfer rows). Schema v1, best-effort writes (never fail the feature if db write fails — snapshot file is truth).

## Guided tasks
1. Read `stats_db.cpp` schema + write path. What happens when db locked/full/corrupt? Confirm feature still returns snapshot (graceful). If not, fix to best-effort.
2. Inspect `stats.db` via Internals-shared copy + `sqlite3` CLI (or Android Studio App Inspection). Query last 10 rows.
3. New table drill (no code): `transfers(at,dir,name,bytes,ms,pc)` (66) — write schema + 2 queries (totals today, per-pc). Review with 66 before implementing.
4. JSON audit: any remaining string-surgery on NESTED payloads? Migrate ONE (duplicates `stats:{...}` from 32 is candidate) to nlohmann.

## Stretch
- Index in SQLite? NO (see 91) until JSON-file index measured slow. Record the measurement first.

## Verify
- [ ] Corrupt-db test still yields snapshot; new-table schema reviewed; one nested builder migrated.
