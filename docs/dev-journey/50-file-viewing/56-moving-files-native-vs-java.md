# 56 — Moving files (rename vs organizer-move vs trash-restore)

## Goal
Pick the right mover per case; stop using `renameTo` where it can't work.

## Touches
- `FileMutator.rename:79` (`renameTo`, same-volume only), `file_organizer.cpp:130-163` (create_dirs + dup-suffix + rename + report), future `trash.hpp` (39)
- `OrganizeHelper.apply`, `BrowseSession`, `NativeCache` invalidation

## How it works today
- Same-folder rename: `FileMutator.rename` (fine).
- Organized moves: native `apply_organize_file` (handles mkdirs, `_dup` collision, per-move errors, report).
- No generic Java move/copy; `renameTo` across volumes/scoped dirs fails silently.

## Guided tasks
1. Decision table: same-dir rename -> FileMutator; planned bulk moves -> organizer plan/apply; trash/restore -> trash API (39); cross-volume single move -> NEW native `move_file(src,dst)`? or copy+delete? Decide + document.
2. Implement `move_file_to_file(src,dst,report?)` in storage module IF needed (payload `src|dst`, dup-suffix, report JSON). JNI ACTION + Java wrapper (copy 24 pattern). Otherwise document why copy+delete suffices.
3. Every move invalidates stats+index. Audit callers; add missing invalidations.
4. UX: move shows dest preview (`from -> to` rows, same as organizer), never silent.

## Stretch
- Progress for 1000-file moves? Serial with counter file (`report.json` streaming)? Design, don't build.

## Verify
- [ ] Same-volume + cross-volume + collision cases all produce correct dest + report.
