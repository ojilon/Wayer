# Wayer — Android end (detailed)

Android app for local file management and transfers with **WayerPC** over hotspot.

This document matches the **current** codebase on branch `ui_home_files_work`.

---

## Prerequisites

- Android Studio or command-line Android SDK  
- **JDK 17**  
- **NDK** (version pinned in `app/build.gradle`, e.g. `29.0.14206865`)  
- **CMake** 3.22+  
- Device or emulator (ABI must be in `aurora.abiFilters`)  
- Optional: PC running WayerPC for Transfer tests  

Min SDK **26**, compile SDK **36**, target SDK **34**.

---

## Clone & branch

```bash
git clone https://github.com/ojilon/Wayer.git
cd Wayer
git checkout ui_home_files_work
```

---

## Configure PC address

```text
app/src/main/java/com/example/wayer/core/Config.java
```

```java
public static final String HOST = "192.168.x.x";  // PC hotspot IP
public static final int PORT = 5000;
```

---

## Build & install

```bash
./gradlew :app:testDebugUnitTest   # unit tests
./gradlew :app:assembleDebug      # debug APK
./gradlew :app:assembleRelease    # release (signing optional)

adb install -r app/build/outputs/apk/debug/app-debug.apk
```

| Output | Path |
|--------|------|
| Debug APK | `app/build/outputs/apk/debug/app-debug.apk` |
| Release APK | `app/build/outputs/apk/release/` |

**Version & ABIs** — edit only `gradle.properties`:

```properties
app.versionCode=1
app.versionName=0.0.1_0
aurora.abiFilters=arm64-v8a,armeabi-v7a,x86_64
```

Signing: copy `keystore.properties.example` → `keystore.properties` (gitignored), or set `WAYER_*` env vars.  
See [docs/RELEASE_AND_BUILD.md](docs/RELEASE_AND_BUILD.md).

---

## App screens

### Home
- Storage used/total from C++ (**Action 7**)
- Category breakdown
- Shortcuts to Files / Storage / Transfer

### Files
- Left drawer (Downloads, DCIM, Movies, Documents, …)
- List directory (**Action 3**)
- Search exact + related (**Action 8**)
- Long-press item → open / rename / delete  
- Long-press path bar → new file / folder  
- Open routes via `FileOpenHelper` → Image / Video / Document activity

### Storage
- Same stats as Home + visual category bars
- **Scan for large files** (**Action 9**, default ≥ 10 MB)
- Long-press → open or delete (`FileMutator`)

### Transfer
- Test TCP connection to `Config.HOST:PORT`
- Optional C++ listener (**Action 6**)
- **Download** = `/ask <name>` → app `filesDir`
- **Upload** = `/upload <name>` from app `filesDir`
- Activity log + rough session stats

---

## Architecture

```text
┌──────────── XML layouts ────────────┐
│  Fragments / Activities (ViewBinding) │
└─────────────────┬───────────────────┘
                  │ display only
┌─────────────────▼───────────────────┐
│  Java: navigation, dialogs, sockets │
│  NetworkManager → WayerPC           │
│  FileMutator → local create/rename/ │
│                delete                 │
└─────────────────┬───────────────────┘
                  │ JNI bulk JSON
┌─────────────────▼───────────────────┐
│  native/ C++23  (NativeEngine)      │
│  list, search, stats, large files   │
└─────────────────────────────────────┘
```

### Native action IDs

| ID | Purpose |
|----|---------|
| 3 | List directory |
| 6 | Start listener |
| 7 | Storage stats |
| 8 | Search files |
| 9 | Find large files |

### Main source map

```text
app/src/main/java/com/example/wayer/
  core/          MainActivity, NativeEngine, Config
  ui/            Home/Files/Storage/Transfer fragments,
                 Document/Image/Video activities, FileAdapter, FileOpenHelper
  network/       NetworkManager, NetworkCallback
  storage/       FileMutator, StorageController, …
  transfer/      TransferController, NetworkStatus
  utils/         TextSanitizer

native/
  wayer_engine.cpp          JNI router
  storage/storage_engine.*  list, stats, search, large files
  transfer/                 listener / network info stubs
  documents/                document filter stub
  third_party/              external C++ libs (local only)
```

---

## Transfer protocol (phone ↔ WayerPC)

```text
Download:
  phone → /ask <filename>
  pc    → FOUND <size>
  phone → /send
  pc    → <bytes>

Upload:
  phone → /upload <size> <filename>
  pc    → READY (or /send)
  phone → <bytes>
```

File names for Transfer UI are **names only** relative to the app files directory (download destination / upload source), not full phone paths.

---

## Tests & CI

```bash
./gradlew :app:testDebugUnitTest
```

- Unit tests: `TextSanitizer`, `FileMutator`, `FileItem`  
- CI: `.github/workflows/android-ci.yml`  
- How to write more: [docs/TESTING.md](docs/TESTING.md)

---

## Documentation index

| File | Topic |
|------|--------|
| [docs/HOME_AND_FILES.md](docs/HOME_AND_FILES.md) | Home + Files flow |
| [docs/STORAGE_AND_TRANSFER.md](docs/STORAGE_AND_TRANSFER.md) | Storage, Transfer, FileMutator |
| [docs/MEDIA_AND_DOCUMENTS.md](docs/MEDIA_AND_DOCUMENTS.md) | Viewers + third_party |
| [docs/RELEASE_AND_BUILD.md](docs/RELEASE_AND_BUILD.md) | Version, ABI, signing, Python tool |
| [docs/TESTING.md](docs/TESTING.md) | Tests |
| [docs/XML_UI_GUIDE.md](docs/XML_UI_GUIDE.md) | Learn / improve XML UI |
| [docs/ICONS.md](docs/ICONS.md) | Vector launcher & nav icons |

---

## Permissions

Declared in `AndroidManifest.xml`:

- `INTERNET`
- `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE` (legacy flag enabled for broader file access on older patterns)

On newer Android versions you may still need runtime grants or scoped-storage adjustments depending on paths you open.

---

## Troubleshooting

| Issue | What to try |
|-------|-------------|
| Build / NDK fails | Install matching NDK; `./gradlew clean`; check `ndkVersion` |
| App only on your phone | Ensure device ABI is in `aurora.abiFilters` |
| Transfer fails | Same hotspot; WayerPC running; correct `Config.HOST`/`PORT` |
| Empty file list | Storage permission; path exists (`/storage/emulated/0/...`) |
| Large scan slow | Expected on full tree; threshold is 10 MB in StorageFragment |
| Release unsigned | Add `keystore.properties` or `WAYER_*` env |

---

## Status notes

- **Usable** for browse, search, local file ops, storage overview, basic PC transfer  
- **Document rendering** (PDF/office) is a placeholder until libraries are added under `native/third_party/`  
- Terminal-style `ls`/`cd` UI is not the primary surface anymore; Files UI + Transfer UI replace that workflow  
