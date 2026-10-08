# 93 — Hashing/dedup design: from FNV to content-addressed thinking

## Goal
Connect 31/32 + 64/68 diff-send to real dedup systems — then steal ONE idea.

## Touches
- `duplicate_finder.cpp` (30/31/32), `TransferQueue` + `POST /session` manifest idea (64.4/68.3), parcel (68.6)

## How it works today
Byte-exact groups via size->partial->full (FNV). No cross-device dedup, no chunking.

## Read (then come back)
- Git internals (objects = hash-addressed, packfiles = delta) — short chapter, big ideas.
- restic design doc (content-defined chunking, dedup across snapshots) — skim, steal vocabulary.

## Guided tasks
1. Whole-file manifest first (NOT chunking): `POST /session [{name,size,xxh3}]` (64.4) -> PC `need[]`. Implement + measure re-send savings on a 20-file repeat set.
2. Chunking? Decide NO for v1 (phone battery + complexity) — write the rejection with numbers (manifest already saves X%).
3. Cross-scan dedup: morning-scan dup groups (40) feed "already on PC?" check? Spec the join (hash equality, not path), don't build yet.
4. Verify-then-delete loop (68.8) as the payoff: hash-confirm (64.3) -> trash-backed delete (39) -> stats refresh. Wire the loop for ONE transfer session.

## Stretch
- Perceptual photo dedup? Explicit OUT (CLEANER_IDEAS Later) — restate why byte-exact stays untouched.

## Verify
- [ ] Manifest diff-send measured; chunking parked with reason; one verify-then-delete loop works.
