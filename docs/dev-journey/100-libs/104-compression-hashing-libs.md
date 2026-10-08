# 104 — Compression + hashing libs (miniz, xxHash, when Zstd?)

## Goal
Fill the two gaps your roadmap actually needs: zip/parse + fast hash. Skip the rest.

## Touches
- ZIP: `docx` text (103.4), offline parcel (68.6); HASH: duplicates (31/32), transfer checksum (61/64.3)
- Candidates: miniz (single-header ZIP, public-domain), xxHash (BSD, XXH3/64), Blake3 (Apache/MIT, overkill?), Zstd (BSD, heavy — skip on phone?)

## How it works today
FNV-1a hand-rolled (duplicate_finder). No zip. No compress.

## Guided tasks
1. **xxHash first (needs you):** vendor per 100 (single `xxhash.h/.c`, `wayer_xxhash` STATIC, cleaner+transfer link). Feature-flag + vectors (82). Wire into `hash64` (31) + `X-File-Hash` (61). Measure vs FNV on 1GB fixture (see 84 bench).
2. **miniz second (needs 103.4/68.6):** vendor single-header (`miniz.h` or `miniz.c`), INTERFACE or tiny STATIC `wayer_miniz`. Use for `docx/document.xml` extract + parcel pack/unpack prototype. Cap unzip (zip-bomb guard: max files + max ratio) — document limits.
3. **Zstd?** NO on phone (binary + battery vs need). Note the rejection so agents stop suggesting it.
4. **Delete-after-use:** every decomp lands in `modules/<job>/` (PathRegistry) + pruned (27 LRU), never shared root.

## Stretch
- CRC vs XXH for parcel integrity? XXH3 already — don't add both. One hash everywhere.

## Verify
- [ ] xxHash vectors green + faster bench; miniz extracts docx text with bomb guards; Zstd rejection recorded.
