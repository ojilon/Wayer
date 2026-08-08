# Testing & CI

## Unit tests (local)

From the repo root:

```bash
./gradlew :app:testDebugUnitTest
```

Reports:

```text
app/build/test-results/testDebugUnitTest/
app/build/reports/tests/testDebugUnitTest/index.html
```

### Current tests

| Class | What it covers |
|-------|----------------|
| `TextSanitizerTest` | Space → underscore sanitizing |
| `FileMutatorTest` | Create file/folder, rename, delete (temp dir) |
| `FileItemTest` | Data class getters |

These are **JVM unit tests** (no emulator). They are safe for your Python tool to invoke the same Gradle task.

## Instrumented tests (device)

Dependencies are already in `app/build.gradle` (`androidTestImplementation`).  
Add classes under:

```text
app/src/androidTest/java/com/example/wayer/...
```

Run:

```bash
./gradlew :app:connectedDebugAndroidTest
```

(Requires a device or emulator.)

## GitHub Actions

Workflow: `.github/workflows/android-ci.yml`

- Triggers on push to `main`, `restructure_ui`, `ui_home_files_work` and PRs to `main` / `restructure_ui`
- Installs JDK 17, Android SDK, NDK/CMake
- Runs `:app:testDebugUnitTest`
- Uploads XML results as an artifact

If CI fails on NDK version mismatch, align `ndkVersion` in `app/build.gradle` with what `sdkmanager` installs, or loosen the install line in the workflow.

## Hooking your Python tool

Minimal sequence:

```text
1. git pull
2. ./gradlew :app:testDebugUnitTest
3. if tests pass → ./gradlew :app:assembleDebug
4. adb install -r app/build/outputs/apk/debug/app-debug.apk
5. optional: run your own device smoke tests
```

Add more unit tests next to the code they protect (same package under `src/test/java/...`).

## What not to test in unit tests

- Real JNI / C++ (`NativeEngine`) — needs device or native unit harness
- Full UI clicks — use Espresso instrumented tests later
- Live hotspot to WayerPC — integration / manual
