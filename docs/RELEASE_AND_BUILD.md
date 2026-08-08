# Build, version, multi-ABI & signing

This guide is written for **you** and for a **Python automation tool** that bumps versions, runs tests, and produces debug/release APKs.

---

## 1. Version numbers (`gradle.properties`)

Only these two keys need to change for a release:

```properties
app.versionCode=1
app.versionName=0.0.1_0
```

| Key | Rule |
|-----|------|
| `app.versionCode` | Integer. **Must increase** every time you install over an older APK (Play Store / Android requirement). |
| `app.versionName` | Any string users see (e.g. `0.1.0`, `0.0.2_1`). |

`app/build.gradle` reads them:

```gradle
versionCode project.property("app.versionCode").toInteger()
versionName project.property("app.versionName")
```

**Python tool:** open `gradle.properties`, regex-replace those two lines, save.

---

## 2. CPU architectures (ABI)

```properties
aurora.abiFilters=arm64-v8a,armeabi-v7a,x86_64
```

| ABI | Typical device |
|-----|----------------|
| `arm64-v8a` | Modern phones (your device) |
| `armeabi-v7a` | Older 32-bit ARM phones |
| `x86_64` | Emulators, some Chromebooks |
| `x86` | Old emulators (optional) |

The NDK builds native `.so` files for each listed ABI and packs them into **one APK**.

- **Faster local debug:** set only `arm64-v8a`.
- **Wider installs:** keep the three defaults above.

Change the property → next `./gradlew assemble*` rebuilds native for those ABIs.

---

## 3. Gradle commands (tool checklist)

From the **repo root** (where `gradlew` lives):

| Goal | Command |
|------|---------|
| Unit tests | `./gradlew :app:testDebugUnitTest` |
| Debug APK | `./gradlew :app:assembleDebug` |
| Release APK | `./gradlew :app:assembleRelease` |
| Clean | `./gradlew clean` |
| Install debug (USB) | `./gradlew :app:installDebug` |

### Output paths

```text
app/build/outputs/apk/debug/app-debug.apk
app/build/outputs/apk/release/app-release.apk   # signed if keystore configured
app/build/outputs/apk/release/app-release-unsigned.apk  # if no signing config
```

Debug builds get `applicationId` suffix `.debug` and version suffix `-debug` so they can sit next to a release install.

---

## 4. Signing a release APK

### One-time: create a keystore

```bash
keytool -genkey -v -keystore wayer-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias wayer
```

### Configure (local)

```bash
cp keystore.properties.example keystore.properties
# edit passwords + path to .jks
```

`keystore.properties` and `*.jks` are **gitignored**.

### Or use environment variables (CI / Python)

```text
WAYER_STORE_FILE=/absolute/path/wayer-release.jks
WAYER_STORE_PASSWORD=...
WAYER_KEY_ALIAS=wayer
WAYER_KEY_PASSWORD=...
```

Then:

```bash
./gradlew :app:assembleRelease
```

If neither file nor env is set, release still builds but may be **unsigned** (fine for local experiments, not for distribution).

---

## 5. Suggested Python pipeline

```text
1. Optionally narrow aurora.abiFilters for speed
2. Set app.versionCode / app.versionName in gradle.properties
3. ./gradlew :app:testDebugUnitTest
4. if fail → stop
5. ./gradlew :app:assembleDebug          # optional smoke install
6. Ensure keystore.properties or WAYER_* env is set
7. ./gradlew :app:assembleRelease
8. Copy APK from app/build/outputs/apk/release/
9. Optional: adb install -r <apk>
```

---

## 6. Notes

- **Never commit** `keystore.properties` or `.jks` files.
- Bump `versionCode` every public APK.
- Multi-ABI makes the APK larger; that is expected.
- Later: Play App Bundle (`bundleRelease`) can split ABIs per device — not required for sideload.
