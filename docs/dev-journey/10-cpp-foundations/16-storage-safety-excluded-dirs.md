# 16 — `safety.hpp`: dirs we never descend / never delete

## Goal
Learn the guardrail before building any delete/auto-clean feature.

## Touches
- `native/storage/include/wayer/storage/safety.hpp`, `native/storage/src/safety.cpp`
- `docs/CLEANER_IDEAS.md:59-64` (Never list), `walker.cpp:33`
- Java: `FileMutator.delete:102`, `OrganizeHelper.apply:68`

## How it works today
- `is_excluded_dir(path)` gates recursion; cleaner ideas doc forbids `Android/data`,
  `Android/obb`, one-tap clean-everything, deletes without preview.
- Destructive actions are preview-first + apply-second (organizer plan/report pattern).

## Guided tasks
1. List every excluded path today. For each, write WHY (system dir, app-private, thumbnail cache loop risk).
2. Add tests-as-comments: `is_excluded_dir("/storage/emulated/0/Android/data") == true`, etc.
3. Improvement: add `is_safe_to_delete(path)` (stricter than walk-exclusion): returns false for root, home, excluded, hidden dotfiles unless explicit. Use it in organizer `apply` + future trash.
4. Document the preview-then-apply contract in `safety.hpp` header comment so future you obeys it.

## Stretch
- Design trash staging API: `trash_move(src) -> trash_path`, `trash_restore`, `trash_expire(days)`. Header-only sketch.

## Verify
- [ ] Walker + organizer still skip excluded; no new deletes without preview path.
