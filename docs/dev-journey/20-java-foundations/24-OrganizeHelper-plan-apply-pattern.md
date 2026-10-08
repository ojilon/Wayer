# 24 — `OrganizeHelper`: plan-then-apply (the destructive-action contract)

## Goal
Master preview-first + apply-second. Every delete/auto-clean must copy this.

## Touches
- `app/src/main/java/com/example/wayer/storage/OrganizeHelper.java:23-106`
- Native: `storage/modules/organizer/src/file_organizer.cpp:55-174`
- `bridge/NativeEngine.java:93-105`, `bridge/PathRegistry.java`, `bridge/NativeCache.java`

## How it works today
- `requestPlan(ctx,root,cb)`: `planOrganizeAsync(root,plan.json)` -> C++ writes plan file -> Java parses `moves[{from,to}]` into preview lists. UI may EDIT the preview.
- `apply(ctx,from,to,onDone)`: Java writes EXACTLY approved moves as plan file -> `applyOrganizeAsync(plan,report)` -> C++ moves (dup -> `_dup` suffix, capped errors) -> `invalidateStatsSnapshot` (moved files would stale stats/index).
- Plan file: `modules/organizer/plan.json`; report: `report.json` (`{moved,failed,skipped,errors[]}`).

## Guided tasks
1. Trace full loop on device with a SCRATCH folder (never real data): plan -> edit preview (drop one move) -> apply -> check report in Internals.
2. Read `apply_organize_file:94-174`. List every `skipped` vs `failed` cause. Which should UI show per-row vs summary?
3. Improvement: per-move status in report (`moved:[...], skipped with reason`)? Or keep counts-only? Implement the smaller extension + update `OrganizeHelper.apply` parse.
4. Safety: enforce organizer NEVER moves `images/others` (today) — move that rule into BOTH C++ and a Java pre-check so UI previews honestly.

## Stretch
- Undo: write inverse plan (`to->from`) alongside report. `Undo` button applies it. Design the UX (snackbar with Undo?).

## Verify
- [ ] Scratch-folder plan->apply->report round-trips; stats refresh clean; no real-data test.
