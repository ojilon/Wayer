# 77 — Splitting Java+XML better (helpers today, ViewModel tomorrow?)

## Goal
Your ask: "splitting the xml and java to better structures." Keep Fragments thin without rewriting to MVVM in one PR.

## Touches
- Fragments: `ui/*Fragment.java`; helpers: `storage/*`, `transfer/*`, `bridge/*`
- `res/layout/*.xml` (ViewBinding), `core/UiChrome.java`, `core/GlassBlur.java`, `core/ThemePrefs.java`

## How it works today
Fragments call helpers (`OrganizeHelper`, `StorageController`, `TransferController`) — good. Some Fragments still fat (parsing JSON in callback? formatting in adapter? navigation strings inline?).

## Guided tasks (rules, then apply to ONE fragment)
1. Rules: Fragment = wire views + observe + navigate. Helper = IO/compute/parse/format. No `new JSONObject` in Fragment (move to helper returning `List<Row>`); no `new File` in Fragment (move to FileMutator/PathRegistry); no raw color/dimen in Java (tokens).
2. Apply to `CleanerFragment` (or Files): extract `CleanerUiMapper` (JSON->rows), `CleanerNavigator` (tab jumps), keep Fragment <300 lines. No behavior change — pure move + rename imports.
3. ViewBinding null-out verified (D3) — keep pattern in every refactor.
4. ViewModel? Decision: introduce `androidx.lifecycle:viewmodel` ONLY when a screen loses state on rotation twice. Until then helpers + `BrowseSession` + `onSaveInstanceState` suffice. Document decision in file header so future-you doesn't rewrite for fashion.

## Stretch
- One screen to ViewModel+LiveData/Flow as SPIKE branch (not merged) to feel the diff. Compare line counts + rotation behavior.

## Verify
- [ ] Target fragment smaller, no JSON/File in it, rotation safe, tests still green.
