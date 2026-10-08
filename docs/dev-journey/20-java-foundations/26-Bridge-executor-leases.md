# 26 — `Bridge` + `FileLeases`: one job at a time, one writer per file

## Goal
Understand why native calls serialize, and how refresh-while-search stays safe.

## Touches
- `app/src/main/java/com/example/wayer/bridge/Bridge.java`, `bridge/FileLeases.java`
- `docs/BRIDGE_PLAN.md:162-176` (Step 3 leases), callers passing lease keys

## How it works today
- `Bridge` owns a SINGLE-thread executor; every `run()` posts there, callback marshalled to UI thread. One native file job at a time.
- `FileLeases.acquire(path,owner,timeout)/release/isFree`: in-memory per-process, stale expire. Refresh/search pass lease keys; refused jobs keep old numbers (`NativeCache` previous-file-first).
- Busy UX: single-retry / already-running message, never torn reads.

## Guided tasks
1. Read `Bridge.java` fully. Note: executor type, how callback reaches main thread, where lease overload lives.
2. Repro: start a search, hit refresh mid-way. What does UI show? (Old list? spinner? error?) Confirm no crash, old numbers kept.
3. Improvement: lease timeout tuning — too short = torn reads, too long = stuck UI. Add logging of acquire-wait ms, review via logcat.
4.Document the busy contract in `Bridge` header: what EVERY caller must do on `busy` (show previous + retry once).

## Stretch
- Cancellation: `Bridge.cancel(owner)`? Design token vs interrupt — native walks need `atomic cancel` (see walker stretch). Sketch API.

## Verify
- [ ] Hammer refresh during search/stats; no torn JSON; logcat shows lease lines.
