# Transfer + Cleaner rework (step by step)

Follows `docs/BRIDGE_PLAN.md` (file-backed bridge) — this file plans the UI
and feature side. Order below is build order: Cleaner + Transfer first,
theme last. One item per change, each ending in `assembleDebug` + install +
tap-through. Check boxes only after the device confirms.

## A — Cleaner tab restructure

- [x] **A1 · Duplicates → Cleaner rename.** (done, build green)
- [x] **A2 · Move large-files scan into Cleaner.** (done: scan + list + delete
  moved verbatim into `CleanerFragment`, converted to the file-backed
  `find_large_files_to_file` on the way; Storage keeps summary + bars)
- [x] **A3 · Cleaner home grid.** (done: 2-column square-card grid with live
  status lines; cards scroll-to + run their utility; disabled "More soon"
  card proves the one-line extension pattern)
- [ ] **A4 · Sideways utility tabs inside Cleaner.** Below a horizontally
  scrollable tab strip (same `ToggleGroup`-in-`HorizontalScrollView` pattern
  as the bottom bar): tapping a card opens its utility as a tab —
  Duplicates tab (existing list UI moved verbatim), Large files tab (moved
  verbatim). Strip always visible; content area swaps. New tabs plug in
  without touching existing ones.

## B — Transfer sub-windows + multi-send queue

- [x] **B1 · Transfer tab strip.** (done: Guide | Transfer | Search | Browse | Network strip + static Guide page; Transfer tab holds only the file-transfer card; Connection/Session/Activity/Recent live in Network; Search tab runs global index search with multi-send, folders jump to Browse)
