# 94 — Scheduling + caching + eviction (OS ideas in a phone app)

## Goal
Morning scans (40), result caches (27), trash expiry (39), queue resume (63) — one design language.

## Touches
- WorkManager worker (40), `PathCache`/`NativeCache` (27), `trash_expire` (39), `TransferQueue` restart rule (63), `stats.db` history (71/101)

## Read (then come back)
- Android WorkManager (constraints, backoff, expedited vs periodic) + Doze/App Standby docs.
- OS caching: LRU/clock, write-back vs write-through, TTL vs invalidation (any OS text, paging chapter — short).

## Guided tasks
1. Policy table (one row per cache/file): key | writer | readers | fresh-until | invalidate-on | max-size/age | on-evict. Fill for: index, search results, dup/large results, stats snapshot, trash, transfer history, morning summary. Commit the TABLE — it kills whole bug classes.
2. Implement ONE eviction (27 `prune()` LRU for `results-*.json` + trash cap from 39). Log evictions (13) at debug.
3. Scheduling: morning worker (40) respects Doze + `BatteryNotLow`/`StorageNotLow` + max-1-notif/day (41). Document constraint choices + test with `TestDriver` (trigger + constraints).
4. Queue resume (63): `sending`->`pending` on restart — prove with kill test. Same "crash = pending" rule for scans (worker retry with backoff, idempotent: re-write same out file).

## Stretch
- Adaptive: skip scan if index fresh + no new files (40 stretch). Implement after policy table proves stable.

## Verify
- [ ] Policy table committed; one eviction + kill-resume proven; worker constraints tested.
