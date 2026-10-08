# 23 — `FileItem` + `FileAdapter`: dumb data, thin adapter, flat rows

## Goal
Learn list UI without business logic. Rows stay dumb; helpers decide.

## Touches
- `app/src/main/java/com/example/wayer/ui/FileItem.java`, `ui/FileAdapter.java`
- `app/src/main/res/layout/item_file.xml`, `app/src/test/java/com/example/wayer/ui/FileItemTest.java`
- `docs/TRANSFER_CLEANER_PLAN.md:27` (D1 flat rows), `docs/XML_UI_GUIDE.md:64-69`

## How it works today
- `FileItem` = name/path/size/isDir (+ maybe ext). No IO.
- `FileAdapter` binds rows: `iconFor(ext)` extension-mapped, checkbox selection (Transfer multi-send), folder filter. Flat style: `radius_xs`, no stroke, spacing+surface separation.
- Empty state pattern: `RecyclerView` + `empty_state` LinearLayout toggle (see XML guide §5).

## Guided tasks
1. Read `FileItem` + `iconFor`. List every ext->icon mapping. Compare with native `EXTENSION_MAP` — fix mismatches (archives?).
2. Improvement 1 (visual): add file-type subtitle (size + date + category) in `item_file.xml` without changing ids. Rebuild, screenshot dark+light.
3. Improvement 2 (behavior): long-press multi-select vs checkbox — pick ONE, keep selection state in adapter not fragment. Document choice.
4. A11y: add `contentDescription` to row icons (see `78-accessibility` later).

## Stretch
- Thumbnail slot: `ImageView` placeholder for images/video; Java loads via MediaStore, NOT in adapter bind (async). Sketch the loader interface.

## Verify
- [ ] Files + Transfer Browse lists still scroll smooth; icons match native categories.
