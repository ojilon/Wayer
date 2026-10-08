# 14 — `extension_map`: category for every file (easiest real improvement)

## Goal
Own the simplest high-value table. Add types, fix case bugs.

## Touches
- `native/storage/include/wayer/storage/extension_map.hpp`
- `native/storage/src/extension_map.cpp:13-26`
- Java mirror: `ui/FileAdapter.java` (`iconFor`), `storage/FileSearcher.java`

## How it works today
- `EXTENSION_MAP`: `.jpg->images`, `.mp4->videos`, `.mp3->audio`, `.pdf/.txt/.docx->documents`, `.apk->foreign`; miss -> `"others"`.
- Lookup lowercases via `core::ascii_lower` so `.JPG` works.
- Organizer skips `others` + `images` (`file_organizer.cpp:68`) — camera-roll safety.

## Guided tasks
1. Add missing: `.opus,.ogg->audio`; `.mov,.3gp->videos`; `.epub,.md,.rtf,.xls/.xlsx,.ppt/.pptx,.csv->documents`; `.zip,.rar,.7z->archives` (new category — update organizer + icons too).
2. Edge: files with no extension (`README`), dotfiles (`.nomedia`), double ext (`tar.gz`). Decide: `others` vs new `no_extension`. Document + implement ONE.
3. Keep Java `FileAdapter.iconFor` in sync — same category strings, or icons lie.
4. Add host-test cases list (even as comments) for each new ext + uppercase variant.

## Stretch
- Propose MIME sniffing fallback (extension lies): read magic bytes for top 8 types. Where would it live? (`core/magic.*`? new `media/` helper?)

## Verify
- [ ] `:app:testDebugUnitTest` + `assembleDebug` green; Storage bars + organizer still correct.
