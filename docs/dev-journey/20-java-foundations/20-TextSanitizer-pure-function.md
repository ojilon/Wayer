# 20 — `TextSanitizer`: the one pure function (Java start here)

## Goal
Write Java without Android. Null-safety, regex, unit tests.

## Touches
- `app/src/main/java/com/example/wayer/utils/TextSanitizer.java:12`
- `app/src/test/java/com/example/wayer/utils/TextSanitizerTest.java`
- Caller: `storage/FileMutator.java:40,64,87` (every create/rename sanitizes)

## How it works today
- `replaceSpacesWithUnderscores(input)`: null->`""`, trim, `\s+`->`_`. Used so
  Transfer protocol tokens never contain spaces (see `TRANSFER_CLEANER_PLAN B3`).
- Pure: no Context, no IO. Testable with plain JUnit (`testDebugUnitTest`).

## Guided tasks
1. Read both files fully (16 lines + test). Run `./gradlew :app:testDebugUnitTest --tests "*TextSanitizer*"`.
2. Add cases: `null`, `""`, `"  a  b  "`, `"a\tb\nc"`, unicode nbsp? Decide: should `trim` also strip? Document.
3. Improvement: `sanitizeFileName` v2 — also strip `/:*?"<>|` (Windows/PC-unsafe chars)? Keep old method, add new, migrate ONE caller.
4. OOP lesson: `static` = no `new TextSanitizer()`. Why is that OK here? (No state.) Contrast with `FileMutator.Result` (tiny value object with `ok+message`).

## Stretch
- Add `toToken(name)` used by Transfer upload: sanitize + ASCII-fold + length-cap. Unit-test it.

## Verify
- [ ] New tests green; no Android import added to this file (keep it pure).
