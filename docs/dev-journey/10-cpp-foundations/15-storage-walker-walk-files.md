# 15 — `walk_files`: the ONE walk every feature reuses

## Goal
Master the 48-line primitive behind duplicates/large/organizer/search/index.

## Touches
- `native/storage/include/wayer/storage/walker.hpp`
- `native/storage/src/walker.cpp:13-46`
- `native/storage/include/wayer/storage/safety.hpp`, `src/safety.cpp`
- Callers: `duplicate_finder.cpp:65`, `large_files.cpp:33`, `file_organizer.cpp:60`

## How it works today
- `walk_files(root, visit)` with `recursive_directory_iterator(skip_permission_denied)`.
- Dirs checked against `is_excluded_dir` -> `disable_recursion_pending()` (don't descend).
- Files: `is_regular_file` -> `visit(entry)`. All `error_code`, no exceptions; broken iterator breaks cleanly.
- Manual `increment(ec)` loop (not range-for) so errors don't throw.

## Guided tasks
1. Read `walker.cpp` line by line. Explain why `ec.clear()` after a dir error, and why `break` on final `increment` error.
2. Read `safety.cpp` — list excluded dirs. Should `Android/`, `.thumbnails`, `MIUI/` be excluded? Propose additions WITHOUT implementing deletes.
3. Improvement (safe): add `walk_files_filtered(root, predicate, visit)`? Or keep callers filtering? Pick one, justify in a comment.
4. Perf: measure on-device walk time for large tree (logcat timestamps around `BUILD_INDEX`). Record baseline in PR.

## Stretch
- Design cancellable walk: `atomic<bool>& cancel` param for UX cancel buttons. Which callers need it first? (large-files, duplicates.)

## Verify
- [ ] No behavior change; timing baseline recorded; exclusions documented.
