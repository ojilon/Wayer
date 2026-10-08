# 30 — Duplicates today: size -> partial-hash -> full-hash

## Goal
Trace the shipped finder before making it realistic.

## Touches
- `native/storage/modules/cleaner/src/duplicate_finder.cpp:22-106`
- `native/storage/modules/cleaner/include/wayer/storage/cleaner.hpp`
- `native/storage/src/walker.cpp`, `native/core/src/text.cpp` (json escape)
- Java: `NativeEngine.findDuplicatesAsync:78`, `ui/CleanerFragment.java` (Duplicates tab)

## How it works today
1. Group by size (`walk_files` + `file_size`); unique sizes dropped (can't dup).
2. Within size group, group by PARTIAL hash (first 4KB FNV-1a mixed with size).
3. Confirm partial collisions with FULL FNV-1a stream (chunked 8KB, never whole file).
4. Emit `{"duplicate_groups":[[path,...],...]}` or `*_to_file` variant `{status,path}`.
- FNV-1a 64: offset 146959..., prime 1099511...; `partial_hash` fallback `size ^ const` on unreadable.

## Guided tasks
1. Read `duplicate_finder.cpp` fully. Explain why size-first saves 99% of hashing on real phones.
2. Trace UI: Cleaner Duplicates tab -> `findDuplicatesAsync(root,out)` -> ACTION 10 -> out JSON -> list groups -> per-item delete (via FileMutator? or native?). Note which.
3. Edge audit: 0-byte files skipped (`sz>0`); unreadable -> fallback hash (could false-group?); symlinks?; same file via two paths? List + decide each.
4. Measure: time + group count on a test folder with known dups (copy a 50MB video x3). Record baseline.

## Stretch
- See `31-duplicates-realistic-*` for hashing upgrades; `33-*` for UI delete UX.

## Verify
- [ ] Known-dup folder yields exactly 1 group of 3; timing baseline recorded.
