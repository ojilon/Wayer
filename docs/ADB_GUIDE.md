# ADB guide: install, logcat, inspect (Wayer)

All commands run from the repo root on your PC. `adb` lives at
`<sdk>/platform-tools/adb` — replace `<sdk>` with your Android SDK path
(or put `platform-tools` on `PATH` and call `adb` directly).
The examples below use a `ADB` placeholder for that binary.

```powershell
$ADB = "<sdk>/platform-tools/adb.exe"
```

Phone prep (once): Settings → Developer options → enable **USB debugging**
(plug in, accept the RSA fingerprint prompt on the phone when asked).

---

## 1. Is the phone visible?

```powershell
& $ADB devices
```

You want your serial plus the word `device`. `unauthorized` means: accept the
prompt on the phone screen, then run it again.

## 2. Build + install the debug APK

```powershell
.\gradlew.bat :app:assembleDebug
& $ADB install -r app/build/outputs/apk/debug/app-debug.apk
```

- `-r` reinstalls over the existing copy. Expect `Success`.
- The debug package is `com.example.wayer.debug` (see the
  `applicationIdSuffix ".debug"` in `app/build.gradle`), so it never touches
  a release install.
- First install (no `-r` needed): drop the `-r` flag.

## 3. Launch from the terminal (optional)

```powershell
& $ADB shell am start -n com.example.wayer.debug/com.example.wayer.core.MainActivity
```

## 4. Watch logs while you tap around

```powershell
& $ADB logcat -c   # clear old noise first
& $ADB logcat | Select-String "WayerNative|AndroidRuntime"
```

- `WayerNative` — our native engine: the `initAppPaths` line prints the
  resolved app root plus the `paths.json` manifest path. If you see
  `paths_not_initialized` anywhere, init never ran.
- `AndroidRuntime` — crashes. A `FATAL EXCEPTION` block here means: copy the
  whole block (it names the file/line) and fix, don't guess.
- Everything else (`BufferQueueProducer` fps lines, `GC freed ...`) is normal
  system noise — ignore it unless you are chasing jank or memory.

## 5. Inspect the private app home (no root needed)

Internal files live under `getFilesDir()` and are invisible to file
explorers — but `run-as` lets you look inside a debuggable build:

```powershell
& $ADB shell run-as com.example.wayer.debug ls -R files/wayer
& $ADB shell run-as com.example.wayer.debug cat files/wayer/paths.json
```

## 6. Uninstall / start clean

```powershell
& $ADB uninstall com.example.wayer.debug
```

Useful to test first-run init from scratch. If an install ever fails with
signature mismatch, uninstall first, then install.

## 7. Signed vs unsigned APKs

- **Debug** (`assembleDebug`): automatically signed with a dev key.
  Installs and runs anywhere. This is what you iterate with.
- **Unsigned release**: Android refuses to install it
  (`INSTALL_PARSE_FAILED_NO_CERTIFICATES` on older versions). There is no
  way around this — a release must be signed.
- **Proper signed release**: create `app/keystore.properties` from
  `keystore.properties.example`, then:

```powershell
.\gradlew.bat :app:assembleRelease
& $ADB install app/build/outputs/apk/release/app-release.apk
```

Verify any APK's signature with:

```powershell
& "<sdk>/build-tools/<version>/apksigner.bat" verify --print-certs app/build/outputs/apk/<variant>/app-<variant>.apk
```

## 8. Typical loop

```powershell
.\gradlew.bat :app:assembleDebug
& $ADB install -r app/build/outputs/apk/debug/app-debug.apk
& $ADB logcat -c
& $ADB logcat | Select-String "WayerNative|AndroidRuntime"
# tap around on the phone, read the filtered output
```
