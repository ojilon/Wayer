# 32 — Partial vs full confirm: correctness without re-reading everything

## Goal
Tune the 3-stage pipeline (size -> partial -> full -> byte-confirm) for phone IO.

## Touches
- `duplicate_finder.cpp:62-92` (the 3 loops), `walker.cpp`, `large_files.cpp` (shares walk)

## How it works today
Size groups -> partial-hash groups -> full-hash groups. Full hash reads ENTIRE file, only for partial collisions (rare). Good. Missing: final byte-compare before delete, and partial quality for big media.

## Guided tasks
1. Instrument: count files at each stage (walked / size-collided / partial-collided / confirmed). Log or stash in JSON `stats:{...}` alongside groups. This tells you where time goes.
2. Add `confirm_bytes_equal(a,b)`: open both, compare chunk-by-chunk, early-exit on first diff. Call ONLY when user taps Delete/Preview-confirm, not during scan. (Scan stays fast; delete stays safe.)
3. Sampling upgrade: partial = head+middle+tail (see 31). Implement here if not done there — don't double-implement; pick ONE file to own it.
4. JSON: add per-group `size`, `count`, `sample_hash`, `confirmed:false` (scan) -> `true` after byte-confirm. Java shows "verified identical" badge.

## Stretch
- Parallel hashing? NO — single executor + phone thermal/battery. Document why serial is a feature.

## Verify
- [ ] Stats show >90% files eliminated at size stage on real tree; delete path byte-confirms.
