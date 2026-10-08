# 54 — Showing file TYPES (icons + labels that never lie)

## Goal
One source of truth for "what kind is this file".

## Touches
- Native: `storage/src/extension_map.cpp`, Java: `ui/FileAdapter.iconFor`
- `res/drawable/ic_*`, `docs/TRANSFER_CLEANER_PLAN.md:29-38` (D2 icon rules), `docs/ICONS.md`
- Viewers: Document/Image/Video activities (which ext opens which)

## How it works today
Two maps (C++ categories, Java icons) that can drift. D2 rules: vectors `drawable/ic_<what>.xml`, raster `drawable-nodpi/img_<what>.webp`, launcher stays `mipmap-*`.

## Guided tasks
1. Diff the two maps. List every ext in one but not the other + every category without an icon. Fix by adding (14) + icons here together.
2. Icon set: add `ic_archives`, `ic_code`, `ic_sheet`, `ic_slide`, `ic_audio`, `ic_apk-warn`? as VectorDrawables (import via Resource Manager, 24dp, `wayer_*` tints). Dark+light check.
3. Label: subtitle shows `PDF · 2.1 MB` (category + size) — implement in `item_file.xml` + adapter (see 23).
4. Unknown: `others` gets a neutral icon + "Open with..." (never a misleading doc icon).

## Stretch
- Magic-byte badge: "extension says .mp4, smells like zip" warning (needs 14 magic sniff). Spec only.

## Verify
- [ ] Every native category has an icon in both themes; unknown never mislabeled.
