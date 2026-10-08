# 31 — Making duplicates REALISTIC: xxhash, size-tiers, sampling

## Goal
Upgrade from demo FNV to a capable finder without losing beginner-readability.

## Touches
- `duplicate_finder.cpp:25-58` (hash core), `native/third_party/` (vendoring, see `100-cpp-libs-*`)
- Candidates: xxHash (XXH3/XXH64), Blake3 (later); keep FNV as fallback when lib missing
- `docs/CLEANER_IDEAS.md:48-56` (perceptual later — NOT this file; byte-exact stays)

## How it works today
Single FNV-1a 64, 4KB partial + full confirm. Fine for small trees, weak for GB videos (slow, higher collision worry, no sampling tiers).

## Guided tasks (in order — one per commit)
1. **Tiered partials:** small files (<1MB): hash whole file once. Medium (1–100MB): 4KB head + 4KB middle + 4KB tail + size. Large (>100MB): 64KB sampled head/tail + size. Implement tier fn, keep FNV first.
2. **Vendor xxHash:** single `xxhash.h`+`xxhash.c` (BSD) under `third_party/xxhash/`, CMake `wayer_xxhash` STATIC, link ONLY cleaner module. Feature-flag: `#ifdef WAYER_HAS_XXHASH` else FNV. (See `100-*` vendoring guide.)
3. **Swap hash call sites:** `partial_hash`/`full_hash` gain `hash64(path,offset,len)` using XXH3 when present. Keep function NAMES so callers don't change.
4. **Collision policy:** document: 64-bit non-crypto + size + byte-confirm on demand (optional final byte-compare for groups user will DELETE). Add `confirm_bytes(pathA,pathB)` for pre-delete check.
5. **Perf:** chunk 64KB–256KB (not 8KB) for large files; measure before/after on same 3x50MB set.

## Stretch
- Blake3 for cryptographic confidence? Probably overkill — document why NOT (binary size, speed vs need).

## Verify
- [ ] Same dup set found; large-file scan measurably faster; no new deps outside cleaner.
