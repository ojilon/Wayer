# 66 — Transfer stats + history (how much, how fast, with whom)

## Goal
"Transfer statistics" from goals.md — real numbers, persisted like stats.db.

## Touches
- `transfer/RecentTransfersStore.java`, future `cache/transfer/history.db` (SQLite — see 101)
- `bridge/Stats.java` pattern (snapshot+history), `NetworkStatus.java`

## How it works today
Recent list in-memory/file? (Read store — note format, cap, prune.) No speed history, no per-PC totals.

## Guided tasks
1. Read `RecentTransfersStore`. Schema? Cap? Survives restart? Add: `{at,dir,name,bytes,ms,pc}` per row, cap 200, prune oldest.
2. Totals card (Network tab): today `X files · Y GB · Z min`, this week, per-PC. Compute from store file (no new native).
3. Speed: per-transfer `bytes/ms` -> show `4.2 MB/s`; session sparkline (see 63 stretch). No chart lib — custom View or text.
4. Export: [Share history CSV] (tiny, high trust for power users).

## Stretch
- SQLite migration when rows >1k: schema `transfers(at,dir,name,bytes,ms,pc)` + index on `at`. Mirror stats.db pattern.

## Verify
- [ ] Totals survive restart; CSV shares; no unbounded file growth.
