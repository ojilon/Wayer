# 55 — Showing file PATHS (breadcrumbs, not walls of text)

## Goal
Users always know where they are + can jump up. No truncated mystery paths.

## Touches
- `ui/FilesFragment.java` (path bar + Up button + `BrowseSession`), `ui/TransferFragment.java` (Browse tab)
- `res/layout/fragment_files.xml` (path bar), `storage/FileNavigator.java`

## How it works today
Path bar + Up button beside it; `BrowseSession` remembers folder (process-scoped). Long paths truncate; no per-segment tap.

## Guided tasks
1. Breadcrumb bar: `storage › Download › big/` — each segment tappable, last ellipsized middle (`…/big/file.mp4` keeps start+end). Implement as horizontal chip strip (RecyclerView) replacing/augmenting TextView — keep old id for compat during migration.
2. Per-row path in search/duplicates/large lists: show parent folder under name (small, `wayer_text_secondary`), tap -> jump to folder in Files/Browse.
3. Copy-path long-press (ClipboardManager) + "Open containing folder". Tiny, high value.
4. Root label: `/storage/emulated/0` -> show `Internal storage` friendly name; keep real path in subtitle.

## Stretch
- Recent paths dropdown (last 10, from prefs). Sketch storage + UI.

## Verify
- [ ] Any depth navigable via crumbs; search result jumps to folder; copy-path works.
