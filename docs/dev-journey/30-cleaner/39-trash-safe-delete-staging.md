# 39 — Trash / safe-delete staging (REQUIRED before auto-delete)

## Goal
Design the safety net every auto/rule delete needs. Do NOT build auto-delete before this.

## Touches
- All deleters: `FileMutator.delete`, organizer apply, duplicates UI (33), empty-folders v2 (36), old-downloads (37)
- New: `files/wayer/trash/<date>/<orig>`, manifest `trash.json`, `safety.hpp`
- Docs: `CLEANER_IDEAS.md:48-58` (Later — needs design first)

## How it works today
Deletes are permanent. That's why auto-clean rules are parked.

## Guided tasks (design-first, then build)
1. API sketch: `trash_move(src)->trash_path`, `trash_restore(trash_path)->orig`, `trash_delete_forever`, `trash_expire(days=30)`. Header-only draft in `storage/include/wayer/storage/trash.hpp` (no impl yet — review first).
2. Collision: trash same-name twice -> suffix `_1`. Restore target exists -> `_restored` suffix, never overwrite. Document.
3. Java: `FileMutator.trashMove` (rename into trash; cross-volume fallback = copy+delete). Every UI delete gains "Undo" snackbar until expiry.
4. Expiry: nodes `trash.json` with `deleted_at`; `trash_expire` runs on app start + before auto-scan (40). Cap trash size (e.g. 1GB or 10% free, whichever smaller).
5. Migrate ONE caller (duplicates delete) to trash; keep others permanent until trash proven.

## Stretch
- Per-type retention (screenshots 7d, APKs 30d, docs 90d)? Propose, don't implement yet.

## Verify
- [ ] Design reviewed; one caller uses trash; restore works; expiry caps size; Internals browses trash.
