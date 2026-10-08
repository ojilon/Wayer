# 84 — Zig beyond build: tooling, vectors, fuzz, perf (where it does a LOT)

## Goal
Your note: "guides where zig can do a lot even beyond the build system."

## Touches
- `collect_context.py`, `transfer/` dir at repo root, `context.txt`, `native/zig/` (from 81/82)

## Jobs for Zig tooling (no APK impact)
1. **Vector generator:** `zig run tools/gen_vectors.zig -- out native/zig/vectors/` — evil filenames, dates, hash tiers (feeds 82 byte-compare + 31/32 stats).
2. **Fuzz harness:** `zig fuzz`? or AFL-style loop over `escape`/`category`/`date_bucket` with random bytes; crash = write vector + fix. Run nightly, not per-build.
3. **Perf bench:** `zig build bench` timing FNV vs XXH3 vs sampled tiers on 1GB fixture (sparse file). Records baseline for 31/32 claims. Output markdown table for PRs.
4. **`collect_context` companion:** `zig run tools/summarize_tree.zig -- native/ app/...` emitting module line-counts + ACTION table (25) staleness check (ACTION ids vs JNI cases). CI lint: fail if table drifts.
5. **Parcel tool** (see 68.6 offline parcel): host-side `.wayerparcel` pack/unpack in Zig (no Android needed) — proves format before phone+PC implement.

## Guided tasks
1. Build ONE tool (4 is cheapest + highest value): tree summarizer that errors when `NativeEngine.java` ACTION list != JNI cases. Wire as CI check.
2. Generate vectors for ONE ported fn (82) with tool 1/2. Commit vectors.
3. Bench ONE hash choice (31) with tool 3. Paste table into the hashing PR.

## Stretch
- WASM preview? `zig build-lib -target wasm32` for docs playground (escape/category demo in browser)? Fun, zero app impact. Only if ahead of schedule.

## Verify
- [ ] 1 tool merged + CI wired; vectors/bench outputs committed with the feature PRs.
