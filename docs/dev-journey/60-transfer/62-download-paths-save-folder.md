# 62 — Downloads: PC->phone save folder + visibility

## Goal
Downloads land somewhere sane, visible to other apps, never in private home.

## Touches
- `storage/FileIndexer.getDefaultSavePath:22` (Download dir or external root or DEFAULT_ROOT)
- `core/AppDirs.java` (`downloadDir()`, `externalRoot()`), `transfer/TransferController.java` (download path)
- Scoped-storage rules (MediaStore on Android 10+), `AndroidManifest.xml` perms

## How it works today
Default save = public Download-ish dir if exists, else external root. Private `getFilesDir()` never used for user downloads.

## Guided tasks
1. On device Android 12/13/14: download a file from PC, find it in system Files app. Note path. Is it `Download/Wayer/`? Should it be? Decide + implement subfolder.
2. Collision: `photo.jpg` exists -> `_1`? `_dup`? Match organizer/copy convention (56/57). Implement ONE rule everywhere.
3. Media scan: notify MediaStore so Gallery finds images now (MediaScannerConnection.scanFile). Add + verify in Photos app.
4. Failure: no space / no perm -> Result with message + [Change folder] action (link to path picker — see 70 Files rethink).

## Stretch
- Per-type subfolders (`Wayer/Images/`, `Wayer/Docs/`)? With opt-out toggle. Propose default.

## Verify
- [ ] Downloaded photo appears in Gallery; collision suffix consistent; low-space error clear.
