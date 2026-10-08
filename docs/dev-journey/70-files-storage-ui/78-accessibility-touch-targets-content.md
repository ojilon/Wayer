# 78 — Accessibility + touch targets (the unsexy differentiator)

## Goal
Every row/button usable one-handed, with TalkBack, at 200% font.

## Touches
- All `res/layout/*.xml`, `res/values/strings.xml` (contentDescriptions), adapters setting `contentDescription`
- Precedent: D3 48dp drawer buttons; guide §7 `contentDescription` note

## How it works today
Partial: drawer fixed; rows/cards/tabs uneven.

## Guided tasks
1. Audit with Accessibility Scanner + TalkBack ON + font 200%: Files rows, Cleaner cards/tabs, Transfer tabs/queue rows, dialogs (rename/create/host). List failures.
2. Fix pass: min 48dp targets, `contentDescription` on every ImageView/icon-button (`"Open photo IMG_1234"` not `"image"`), `labelFor` on inputs, touch delegate where icon <48dp.
3. Dynamic text: `sp` for text (never `dp`), single-line ellipsize where truncation honest (paths keep start+end? see 55), test 200% no overlap (ConstraintLayout barriers help — see 76).
4. Color: contrast check `wayer_text_secondary` on `wayer_surface` both themes (4.5:1 for text). Fix tokens, not per-view hacks.

## Stretch
- Keyboard/D-pad navigation (TV? no — but foldables/desks): focus order sane, visible focus. Quick pass.

## Verify
- [ ] Scanner clean on 3 screens; TalkBack reads rows/tabs/dialogs sensibly; 200% no clip.
