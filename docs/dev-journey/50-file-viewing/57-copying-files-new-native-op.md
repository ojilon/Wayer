# 57 — Copying files (the missing op — spec it right)

## Goal
Add copy without OOM, with progress + cancel + collision policy.

## Touches
- New: `native/storage/src/copy.cpp` (proposed) + `storage.hpp` entry; JNI ACTION; `NativeEngine.copyFileAsync` (new)
- Java: `FileMutator.copy` (small files, streams) vs native copy (large/bulk)
- `walker` cancel pattern (15 stretch), `Bridge` busy (26), notifications? (41 for completion?)

## How it works today
No dedicated copy. Java `renameTo` isn't copy; streams in `FileMutator` (21) cover tiny cases only.

## Guided tasks
1. Spec: payload `src|dst`, response `{status,path}`, options `overwrite?|cancel_token?`. Collision: `_copy`/`_copy2` suffix (mirror organizer `_dup`). Decide + freeze spec first.
2. Native: buffered streams (64–256KB), preserve mtime? (`last_write_time` set), partial-on-cancel cleanup (delete half-file), `error_code` everywhere, no exceptions.
3. Java: small (<10MB?) via `FileMutator.copy` inline; large via native async with progress file (`{done_bytes,total}` polled)? Or callback-only? Pick simplest that shows progress.
4. UI: Files long-press [Copy] [Paste here] with paste-bar (source chip + Cancel). Paste into same folder = duplicate with suffix. Invalidate caches.

## Stretch
- Folder copy (recursive)? v2 — spec collision + cancel first.

## Verify
- [ ] 1GB file copies without OOM, cancel leaves no half-file, collision suffix correct.
