# 04 — Build / run / test loop (your safety net)

## Goal
Make build+test muscle memory so experiments are cheap.

## Touches
- `docs/TESTING.md`, `docs/ADB_GUIDE.md`, `app/build.gradle`, `gradle.properties`
- `app/src/test/java/com/example/wayer/` (`TextSanitizerTest`, `FileMutatorTest`,
  `NetworkManagerTest`, `FileItemTest`)
- `keystore.properties.example`, `.github/workflows/`

## How it works today
- Unit tests: `./gradlew :app:testDebugUnitTest` (pure Java, no device).
- APK: `./gradlew :app:assembleDebug` -> `app/build/outputs/apk/debug/app-debug.apk`.
- Device: `adb install -r <apk>`, `adb logcat -s WayerBridge`, Internals tab for files.
- Native: `native/CMakeLists.txt` via `externalNativeBuild`; `compile_commands.json`
  copied to `build/` for clangd.
- Signing/version: `gradle.properties` (`app.versionCode`, `aurora.abiFilters`).

## Guided tasks
1. Run unit tests now, note green. Break `TextSanitizer` on purpose, re-run, see red, revert.
2. Build debug APK, `adb install`, open every tab once, open Internals, find `paths.json`.
3. Run `adb logcat` while tapping Cleaner -> Duplicates. Find the bridge tag lines.
4. Change one string in `res/values/strings.xml`, rebuild, see it on device.

## Stretch
- Add a new unit test for an edge case you find (empty root, zero bytes).

## Verify
- [ ] Both gradle commands pass from memory.
- [ ] You know where APK + `paths.json` live.
