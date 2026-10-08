# 37 — Old downloads + stale APKs (age + extension presets)

## Goal
Two cheap presets on the large-files engine with age filtering.

## Touches
- `large_files.cpp` (+ new `older_than_days` param), `extension_map.cpp` (apk/docs/video)
- Java presets in Cleaner tabs; `FileIndexer.getDefaultSavePath()` (Download dir)
- `organizer/file_organizer.cpp:29` (`date_bucket` via `last_write_time` — reuse pattern)

## How it works today
`find_large_files(root,min,max)` has no age filter. Old-downloads (Download/ untouched 90+d, biggest first) and stale APKs (`*.apk` in Download/) are listed as Next/cheap in CLEANER_IDEAS.

## Guided tasks
1. Native: add `find_old_files(root,min_bytes,older_than_days,max,out)` OR extend large-files payload with optional field (back-compat: missing = 0 = no age filter). Pick one, keep old callers working.
2. Time helper: extract `date_bucket` logic into shared `core/time.hpp` (`days_since_write(path)`) — both organizer + this use it. Don't duplicate chrono code.
3. Java: two presets (reuse Large-files tab with preset spinner? or two cards sharing one tab?). Cheapest: one "Old files" tab with preset chips [Downloads 90d] [APKs] [Videos 180d].
4. Safety: preview-only first; per-item delete; never touch `Android/`; APK delete warns "installer copy — app stays installed".

## Stretch
- "Open containing folder" + "Share" actions per row (Intent) — small, high delight.

## Verify
- [ ] Known old 100MB file in Download/ appears; fresh file doesn't; APK preset lists only .apk.
