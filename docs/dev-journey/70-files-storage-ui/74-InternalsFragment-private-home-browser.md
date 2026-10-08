# 74 — Internals: read-only browser of private home (your debugger UI)

## Goal
Keep the most useful dev screen in the app — make it user-safe.

## Touches
- `app/src/main/java/com/example/wayer/ui/InternalFragment.java`, `res/layout/fragment_internal.xml`
- `bridge/PathRegistry.java` (manifest), every `modules/*`, `cache/*`, `logs/*` file

## How it works today
Read-only browser of private home (index, cache, logs, manifest). Bottom-nav destination.

## Guided tasks
1. Guarantee: EVERY new native out-file appears here (add registry for scan/morning/transfer-history files as you add them). Checklist in each feature PR.
2. File rows: name + size + mtime + [View] (text preview for .json/.log via 51 path, metadata for binary). Reuse preview, don't duplicate.
3. Actions: [Copy path] [Share] per file (debug superpower); [Prune old results] (wires 27 LRU). NO delete-all (safety).
4. Hide? Keep visible in debug, gate in release? Decide: keep, but rename "App data" with subtitle "diagnostics — safe to look, careful to share (may contain filenames)".

## Stretch
- Log viewer: tail `logs/engine.log` live (see 13 stretch). Cheap TextView + refresh.

## Verify
- [ ] New morning-scan + transfer-history files visible; share works; no delete-all.
