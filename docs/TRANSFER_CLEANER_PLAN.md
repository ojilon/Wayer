# Transfer + Cleaner rework (step by step)

Follows `docs/BRIDGE_PLAN.md` (file-backed bridge) — this file plans the UI
and feature side. Order below is build order: Cleaner + Transfer first,
theme last. One item per change, each ending in `assembleDebug` + install +
tap-through. Check boxes only after the device confirms.

## A — Cleaner tab restructure

- [ ] **A1 · Duplicates → Cleaner rename.** `DuplicatesFragment` becomes
  `CleanerFragment` (`fragment_cleaner.xml`, menu id `nav_cleaner`), title
  "Cleaner". Pure rename + rebuild + launch; nothing else moves yet.
- [ ] **A2 · Move large-files scan into Cleaner.** Relocate `scanLargeFiles`,
  `parseLargeFiles`, the results list and its button from `StorageFragment`
  to the Cleaner large-files tab. Storage keeps summary + category bars
  (room there for future non-cleaner widgets). `StorageFragment` shrinks;
  no behavior changes on either screen.
- [ ] **A3 · Cleaner home grid.** Cleaner opens on a 2-column vertical grid
  of **square cards** (icon top, label + status line below), not buttons:
  Duplicates, Large files (+ future cards from `CLEANER_IDEAS.md`, each a
  one-line addition to the card list). New `item_cleaner_card.xml` +
  `CleanerCardAdapter`. Card status lines come from result files where they
  exist ("1.2 GB in 34 files"), plain labels where not yet.
- [ ] **A4 · Sideways utility tabs inside Cleaner.** Below a horizontally
  scrollable tab strip (same `ToggleGroup`-in-`HorizontalScrollView` pattern
  as the bottom bar): tapping a card opens its utility as a tab —
  Duplicates tab (existing list UI moved verbatim), Large files tab (moved
  verbatim). Strip always visible; content area swaps. New tabs plug in
  without touching existing ones.

## B — Transfer sub-windows + multi-send queue

- [ ] **B1 · Transfer tab strip.** Same pattern as A4: [Guide | Transfer |
  Browse]. Guide = the existing "how to test the connection" steps as a
  static help page (today that knowledge lives only in docs). Transfer =
  current send/receive UI. Browse = current folder browser, upgraded below.
- [ ] **B2 · Multi-select + one-by-one queue.** Browse list gains selection
  mode (checkbox rows via `FileAdapter` selection set): tick files under the
  opened folder → "Send selected" saves the path list to
  `modules/transfer/queue.json` → uploader pushes **one file per `/upload`**
  in order, marking each pending/sending/done/failed in a session list under
  the window. Queue file survives rotation; a second tap appends, never
  duplicates (dedupe on save).
- [ ] **B3 · Space-in-filename upload fix (bug).** Root cause: the `/upload`
  command is space-separated (`/upload <size> <basename>`), so the PC parses
  `file name` as two tokens. Fix: sanitize **the protocol token only** with
  `TextSanitizer.replaceSpacesWithUnderscores` when building the command —
  the local file is never renamed, the PC receives `file_name`. Same guard
  on the `/ask` *display* path is NOT applied (the PC looks up its own real
  names there). Add a pure-function note so it stays testable.
- [ ] **B4 · Browse memory + refresh + Up.** Browsing remembers its folder
  (and restores folder + contents after any refresh), refresh re-reads from
  disk (never from a stale list), and an Up button climbs the tree like the
  Internals tab. State lives in a process-scoped holder: survives rotation
  and tab-hopping, dies with the process (never persisted = "resets only on
  full close" for free).
- [ ] **B5 · Session UI.** Below the transfer controls: the queue with per-file
  status rows + session totals. One uploader, sequential, cancellable
  between files (never mid-file).

## C — Files tab session memory

- [ ] **C1 · Return where you left.** `FilesFragment.currentPath` resets to
  root on every visit today. Move it into the same process-scoped holder as
  B4 (per-tab keys: files / transfer-browse). Leaving the tab and coming
  back restores folder + list; killing the app resets. Plus an explicit Up
  button next to the path bar.

## D — Theme, rows, icons

- [ ] **D1 · Flatten file/folder rows.** `item_file.xml` today: 8dp corners +
  1dp glass stroke reads as chunky buttons. New row: 4dp corners (new
  `radius_xs`), no stroke, list separated by spacing + surface contrast.
  One layout edit, every list in the app improves at once.
- [ ] **D2 · Real file-type icons.** Extend `FileAdapter.iconFor` (already
  extension-mapped) with new glyphs. Asset rules for anything downloaded:
  - **Vectors** (icons, glyphs): `res/drawable/ic_<what>.xml`
    (VectorDrawable, any density, tiny). Convert SVG via Android Studio
    Resource Manager → Import, or hand-write like `ic_nav_debug.xml`.
  - **Raster art** (photos, rich images): single copy in
    `res/drawable-nodpi/img_<what>.webp` (WebP, never multi-density PNGs
    by hand). Launcher icons stay in `mipmap-*`.
  - Each future item names its exact files; nothing lands anywhere else.
- [ ] **D3 · Modern-practice audit.** One pass: no hardcoded colors/text in
  layouts (theme attrs + `strings.xml`), `contentDescription` on every
  `ImageView`, 48dp touch targets, `values-night` parity for every new
  color, ViewBinding null-out (already the pattern — keep it).

## Build order (proposed)

A1 → A2 → B3 (bug, tiny) → A3 → A4 → B1 → B2 → B4 → C1 → B5 → D1 → D2 → D3.
Say which to start with; default is A1.

## Out of scope for this file

- Native transfer protocol changes (PC side untouched — the sanitize fix is
  phone-side token shaping only).
- Auto-clean rules, trash system (see `CLEANER_IDEAS.md` "Later" — needs its
  own design doc first).
- Rich document rendering (`preview` module + third-party engines continue
  on their own track).
