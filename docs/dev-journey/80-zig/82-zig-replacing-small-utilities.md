# 82 — Zig ports: small utilities behind the same headers (one fn at a time)

## Goal
Slowly let Zig "participate" where it enforces better habits — without forking behavior.

## Touches
- Ports (in order): `ascii_lower` (10) -> `json::escape/quote` (11) -> `days_since_write/date_bucket` (37) -> `hash64 sampled` (31)
- Pattern: C++ header UNCHANGED; impl swaps to `extern "C"` Zig fn OR Zig static lib linked to module

## How it works today
All C++ (see 10/11/14). Tests: on-device + host reasoning; no host harness.

## Guided tasks (per fn — repeat the loop, one PR per fn)
1. Spec freeze: signature + edge cases (null? empty? non-ASCII? NUL bytes?) as COMMENTS + host test vectors (evil filenames, dates, hashes). Tests FIRST, in BOTH C++ host runner AND `zig test`.
2. Zig impl in `native/zig/src/<name>.zig` with `export fn <name>(...)` C ABI. Explicit allocator (`std.testing.allocator` in tests, fixed buffer or `c_allocator` at boundary — document choice).
3. Link: module `target_link_libraries(... PRIVATE wayer_zig_<name>)` (static). Keep C++ fallback via `#ifdef WAYER_HAS_ZIG_<NAME>` so missing-zig builds still pass (see 81 non-fatal rule).
4. Byte-compare: run old vs new on 10k real filenames/paths on host; diff must be EMPTY. Commit vectors as `native/zig/vectors/<name>.txt`.
5. Delete fallback ONLY after 2 green releases. Never keep two truths long-term — note removal PR in code comment.

## Stretch
- `walk_files` in Zig (`std.fs.walk`)? Heavier (OS interplay) — do LAST, after 3 small ports prove the pipeline.

## Verify
- [ ] Vectors committed; C++ + Zig tests green; APK behavior identical; fallback removal scheduled.
