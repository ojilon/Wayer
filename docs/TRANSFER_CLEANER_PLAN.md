# Transfer + Cleaner rework (step by step)

Follows `docs/BRIDGE_PLAN.md` (file-backed bridge) — this file plans the UI
and feature side. Order below is build order: Cleaner + Transfer first,
theme last. One item per change, each ending in `assembleDebug` + install +
tap-through. Check boxes only after the device confirms.

## A — Cleaner tab restructure

- [x] **A1 · Duplicates → Cleaner rename.** `DuplicatesFragment` becomes (done, build green)
- [x] **A2 · Move large-files scan into Cleaner.** Relocate `scanLargeFiles`, (done: scan + list + delete moved into `CleanerFragment`, converted to file-backed `find_large_files_to_file`; Storage keeps summary + bars)
- [x] **A3 · Cleaner home grid.** Cleaner opens on a 2-column vertical grid (done: 2-column square-card grid, live status lines, cards scroll-to + run their utility, disabled More-soon card)
- [x] **A4 · Sideways utility tabs inside Cleaner.** Below a horizontally (done: Utilities/Duplicates/Large-files strip + flipper; new utilities add one button + one child)
## B — Transfer sub-windows + multi-send queue

- [x] **B1 · Transfer tab strip.** Same pattern as A4: [Guide | Transfer | (done: Guide | Transfer | Search | Browse | Network strip + static Guide page; Transfer tab holds only the file-transfer card; Connection/Session/Activity/Recent live in Network; Search tab runs global index search with multi-send, folders jump to Browse)
- [x] **B2 · Multi-select + one-by-one queue.** Browse list gains selection (done: checkbox selection in shared row layout, folder filter, queue.json with per-file status, sequential uploader with session log lines; queue is replaced per send (append/dedupe moves to the B5 session UI))
- [x] **B3 · Space-in-filename upload fix (bug).** Root cause: the `/upload` (done: protocol token sanitized, local file untouched, pure builder + 3 unit tests, suite green)
- [x] **B4 · Browse memory + refresh + Up.** Browsing remembers its folder (done: process-scoped `BrowseSession`, Up button, disk-fresh refresh into the remembered folder)
- [x] **B5 · Session UI.** (done: queue rows with live pending/sending/done/failed status read from the same queue file, session status line, cancel-between-files flag, totals in the Network session card)

## C — Files tab session memory

- [x] **C1 · Return where you left.** `FilesFragment.currentPath` resets to (done: `currentPath` lives in `BrowseSession`, Up button beside the path bar)
## D — Theme, rows, icons

- [x] **D1 · Flatten file/folder rows.** (done: 4dp radius_xs, stroke removed, spacing+surface separation)

- [ ] **D2 · Real file-type icons.** Extend `FileAdapter.iconFor` (already
  extension-mapped) with new glyphs. Asset rules for anything downloaded:
  - **Vectors** (icons, glyphs): `res/drawable/ic_<what>.xml`
    (VectorDrawable, any density, tiny). Convert SVG via Android Studio
    Resource Manager → Import, or hand-write like `ic_nav_debug.xml`.
  - **Raster art** (photos, rich images): single copy in
    `res/drawable-nodpi/img_<what>.webp` (WebP, never multi-density PNGs
    by hand). Launcher icons stay in `mipmap-*`.
  - Each future item names its exact files; nothing lands anywhere else.
- [x] **D3 · Modern-practice audit.** (done: 113 strings extracted to values/strings.xml, night parity for wayer_cat_sys, 48dp drawer buttons, binding null-out verified everywhere)

## Build order (proposed)

Done: A1 → A2 → B3 → A3 → A4 → B1 → B2 → B4 → C1.
Remaining: B5 → D1 → D2 → D3.

## Out of scope for this file

- Native transfer protocol changes (PC side untouched — the sanitize fix is
  phone-side token shaping only).
- Auto-clean rules, trash system (see `CLEANER_IDEAS.md` "Later" — needs its
  own design doc first).
- Rich document rendering (`preview` module + third-party engines continue
  on their own track).
