# 75 — Icons: vectors for glyphs, WebP for art (never hand PNGs)

## Goal
Finish D2 properly: every category + nav + action has a crisp icon in both themes.

## Touches
- `res/drawable/ic_*.xml` (VectorDrawable), `res/drawable-nodpi/img_*.webp`, `mipmap-*` (launcher only)
- `ui/FileAdapter.iconFor`, nav bar, Cleaner cards, Transfer tabs
- Docs: `TRANSFER_CLEANER_PLAN D2`, `docs/ICONS.md`

## How it works today
`iconFor` extension-mapped; D2 pending new glyphs. Rules: vectors for icons, single WebP nodpi for art, launcher in mipmap.

## Guided tasks
1. Inventory: every `ic_*` + every `iconFor` branch + every nav/tab icon. Missing: archives/code/sheet/slide/apk-warn/trash/refresh-warn? List.
2. Import via Android Studio Resource Manager (SVG->Vector) or hand-write like `ic_nav_debug.xml`. 24dp, `?attr/colorControlNormal` or `wayer_*` tints (never hardcoded `#`).
3. Night check: each icon on dark+light + selected/unselected nav states. Screenshot both.
4. Cleaner cards: each utility gets glyph + status-line icon (dup/link, large/weight, empty/folder-open, old/clock, apk/box). Keep 1 style (rounded? outline?).

## Stretch
- Adaptive launcher icon (foreground/background)? Only if current looks dated on Android 13+ themed icons. Small.

## Verify
- [ ] No missing-icon fallbacks in lists/nav/cards; both themes screenshot-approved.
