# 21 — `FileMutator`: create/rename/delete + `Result` pattern

## Goal
Own local mutations. The `Result{ok,message}` habit that replaces exceptions.

## Touches
- `app/src/main/java/com/example/wayer/storage/FileMutator.java:18-172`
- `app/src/test/java/com/example/wayer/storage/FileMutatorTest.java`
- Callers: `ui/FilesFragment.java` (create/rename/delete dialogs)

## How it works today
- `Result{ok,message}` + `success()/fail()` factories. Every op returns Result, never throws to UI.
- `createFile/createDirectory` sanitize via TextSanitizer, `mkdirs`, `createNewFile`.
- `rename` = `File.renameTo` (same volume); `delete` = recursive; `writeTextFile` for small configs.
- Header comment says: heavy bulk work can move to C++ later, method names stay so UI doesn't change.

## Guided tasks
1. Read `FileMutator.java` fully. For each method list: null-checks, exists-checks, IO try/catch.
2. Bug hunt: `renameTo` fails silently across volumes / on scoped storage. When should Java delegate to native `apply_organize`-style move instead? Write the decision table.
3. Improvement 1: `copy(File src, File dest)` — streams, no whole-file alloc, overwrite flag. Add + unit test with temp dirs.
4. Improvement 2: after every mutation, invalidate native caches (`NativeCache.invalidateStatsSnapshot` + index). Find who forgets to — fix ONE caller.
5. Safety: wire `is_safe_to_delete` thinking from `16-safety`: refuse to delete root, `Android/`, empty path. Return `Result.fail`, never throw.

## Stretch
- Move-to-trash: `trashMove(path)` (rename into `files/wayer/trash/<date>/...`) + `restore`. Preview the design in CLEANER_IDEAS Later terms.

## Verify
- [ ] `FileMutatorTest` green + new copy/safety tests; Files tab create/rename/delete still works on device.
