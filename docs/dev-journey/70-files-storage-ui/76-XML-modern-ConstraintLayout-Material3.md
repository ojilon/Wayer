# 76 — Modern XML: ConstraintLayout + Material3 (kill nested-soup)

## Goal
Your ask: "improving on the xml (using modern ways to draw the ui and ux)."

## Touches
- `res/layout/*.xml`, `res/values/{colors,dimens,themes,strings}.xml`, `res/values-night/colors.xml`
- `docs/XML_UI_GUIDE.md` (tokens, blocks, spacing, empty-states, safe-improve loop)
- Deps already: `material:1.11.0`, `constraintlayout:2.1.4`, `recyclerview:1.3.2`

## How it works today
LinearLayout stacks + FrameLayout overlays + ScrollView single-child + MaterialCardView + RecyclerView + MaterialButton/TextInputLayout. Tokens centralized. D3 extracted 113 strings, night parity for `wayer_cat_sys`, 48dp drawer buttons.

## Guided tasks (one screen at a time)
1. Pick worst soup (likely `fragment_transfer.xml` or `fragment_storage.xml`): flatten nested LinearLayouts (>3 deep) into ONE ConstraintLayout with chains/barriers. Keep ALL `android:id`s stable (binding!). Measure: depth before/after (Layout Inspector).
2. Material3: `MaterialCardView` (tonal? keep `wayer_surface` + `radius_md`), `MaterialButton` styles (filled/tonal/outlined per hierarchy — primary action filled, rest tonal/text), `TextInputLayout` for every EditText (search, rename, host/port).
3. Motion: shared-element? NO. Start with `MaterialSharedAxis` between Cleaner tabs? Or simple fade. One transition, subtle, tested on low-end.
4. Dark/light: every new `@color` gets night value day-one. Every new `@dimen` reuses token (no `17dp` magic).

## Stretch
- Edge-to-edge + WindowInsets (status/nav bars)? Needs `MainActivity` chrome work (see 77). Spec with screenshots.

## Verify
- [ ] One screen flattened, ids stable, strings-only (no literals), both themes, 48dp targets.
