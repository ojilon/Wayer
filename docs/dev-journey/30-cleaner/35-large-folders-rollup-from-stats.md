# 35 — Large folders rollup (cheap card — data already exists)

## Goal
Ship the cheapest new card: top folders by bytes from stats snapshot.

## Touches
- `native/storage/src/stats_json.cpp`, `stats_db.cpp`, `include/wayer/storage/stats_json.hpp`
- Snapshot file: `cache/stats/snapshot.json` (`folders[]` array already there per CLEANER_IDEAS)
- Java: `bridge/Stats.java`, `ui/StorageFragment.java`, new Cleaner tab (copy Large-files tab pattern)

## How it works today
Every stats snapshot already contains per-folder bytes. Card just lists top folders; tap drills into folder (Files/Browse).

## Guided tasks
1. Inspect a real `snapshot.json` in Internals. Find `folders[]`. Note sort order, depth, cap.
2. Native: DONE (per doc). Java: new sideways tab (TRANSFER_CLEANER_PLAN A4 pattern: one button + one flipper child). Reuse row layout.
3. Drill-in: tap folder -> `BrowseSession` set path -> jump to Files/Browse tab. Implement navigation, not new listing.
4. Status line on card home grid: `"Top: DCIM · 4.2 GB"`. Compute from snapshot without rescan.

## Stretch
- Treemap? NO — list first. Custom View bar per folder (reuse Storage bars).

## Verify
- [ ] Card shows without extra native scan; tap drills correctly; rotation keeps list.
