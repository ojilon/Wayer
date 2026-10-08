# 90 — When to go read system design, then come back (the middle-stage gate)

## Goal
Your ask: "at later/middle stages when I'm comfortable, where to go read system design/algos and come back to implement."

## Gate (don't read these before)
- You can trace any feature (03) without notes.
- You shipped 1 native improvement (14/34) + 1 Java improvement (20/21) + 1 UI slice (70/76).
- `testDebugUnitTest` + `assembleDebug` + adb+Internals are boring routine (04).
If not yet: stop here, go back to `10/20/30/`. These files wait.

## How to read-then-come-back (loop per topic)
1. Read ONE source (book chapter / paper / blog) — take notes as QUESTIONS, not highlights.
2. Answer in THIS repo: which file would change? Write the header sketch FIRST (no impl).
3. Implement smallest slice behind flag/fallback (see Zig 82 pattern). Measure before/after.
4. PR with numbers (timing, bytes, rows). Park the rest with reasons.

## Sources by topic (starters — add your own)
- Indexing (91): DB design ch on LSM vs B-tree (any of Kleppmann DDIA ch3-4, SQLite docs on indexes/WAL); then decide JSON-file vs SQLite for YOUR index.
- Search (92): trigram indexes (SQLite FTS5 docs, Postgres pg_trgm docs); then scoped vs global search split (28/67).
- Hashing/dedup (93): content-addressed storage (Git internals ch, restic design doc); then 31/32 tiers + 64.4 diff-send.
- Scheduling/caching (94): WorkManager guides + OS battery docs; LRU/clock + write-back vs write-through (any OS text ch on paging); then 40/41 + 27 prune.
- Protocol (64): HTTP range/resume (RFC 7233 digest), mDNS/DNS-SD specs; then handshake/caps/diff-send.

## Guided tasks
1. Pick ONE topic (91 recommended first — it gates index futures). Do the loop once, end to end.
2. File the "parked with reasons" note for what you DIDN'T build (e.g. "delta index parked: rebuild 1.2s < 5s threshold").

## Verify
- [ ] 1 read->build loop shipped with numbers; parked notes honest.
