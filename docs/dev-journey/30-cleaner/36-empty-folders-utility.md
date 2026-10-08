# 36 — Empty folders finder (safe, preview-only first)

## Goal
Add a medium-cheap utility end to end (your first new ACTION).

## Touches
- New: `native/storage/modules/cleaner/src/empty_folders.cpp` + `cleaner.hpp` entry
- JNI: new `ACTION_LIST_EMPTY_FOLDERS=20` (spec in `18-jni-*` first)
- Java: `NativeEngine.listEmptyFoldersAsync` (new wrapper), Cleaner new tab
- Safety: `safety.hpp` exclusions + `is_safe_to_delete` (16)

## How it works today
Doesn't exist. Design: recursive walk collecting zero-entry dirs (post-order: child empty + parent becomes empty after? decide).

## Guided tasks
1. Spec: payload `root|out_path`, response `{status,path}`, result `{count,folders:[path,...]}`. Write spec BEFORE code (review with 18).
2. Native: implement with `walk_files` + `is_empty(ec)` check; EXCLUDE app dirs; cap results (e.g. 500).
3. JNI + Java wrapper + tab (copy large-files tab, minimal). Preview-only v1: list + "Open in Files", NO delete button yet.
4. v2: delete with per-item confirm + `trashMove` (39) + invalidate. Never bulk-delete without listing first (CLEANER_IDEAS Never).

## Stretch
- "Empty after move" detection: organizer report -> suggest empty-folder rescan. Wire the hint link.

## Verify
- [ ] Scratch tree with nested empties lists correctly; app dirs never listed; no delete in v1.
