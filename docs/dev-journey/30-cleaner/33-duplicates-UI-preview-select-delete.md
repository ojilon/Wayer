# 33 — Duplicates UI: preview, select-keep-one, safe delete

## Goal
Turn raw groups into a trustworthy "keep one, delete rest" flow.

## Touches
- `ui/CleanerFragment.java` (Duplicates sideways tab, see TRANSFER_CLEANER_PLAN A4)
- `res/layout/fragment_cleaner.xml`, `item_file.xml` (reuse), `OrganizeHelper.java` (pattern to copy: preview->apply)
- `FileMutator.delete:102`, future `trashMove` (see 39)

## How it works today
Groups listed; per-item delete exists but UX is bare (no keep-one shortcut, no byte-confirm badge, no trash).

## Guided tasks
1. Group header: `N files · X MB reclaimable · verified?` Compute from group JSON (size* (count-1)).
2. Keep-one UX: per group, radio-pick keeper (default newest? or first?). "Select all except keeper" button. Delete = move-to-trash (39) not permanent — at least until trash ships, require per-group confirm dialog listing paths.
3. Preview: tap file -> existing preview (Document/Image/Video activity) so user SEES before deleting. Wire it — don't build a new viewer here.
4. Post-delete: invalidate stats+index (`NativeCache.invalidateStatsSnapshot`), rescan that group only (or drop group from list optimistically + snackbar Undo if trash exists).

## Stretch
- "Smart keeper": prefer file in DCIM/Camera over Download copy; prefer longer path? Document heuristic + let user override.

## Verify
- [ ] Delete flow: preview -> select keeper -> confirm -> trash/delete -> stats refresh; rotation doesn't lose selection.
