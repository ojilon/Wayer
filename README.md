# Wayer (Android)

Android client for browsing local storage and transferring files with **WayerPC** over a phone hotspot.

**Active UI branch:** `ui_home_files_work` (built on top of `restructure_ui`)

| Doc | Purpose |
|-----|---------|
| [README_ANDROID_END.md](README_ANDROID_END.md) | Full Android setup, structure, usage |
| [docs/](docs/) | Feature guides (Home, Files, Storage, Transfer, tests, icons, XML) |

---

## Quick start

```bash
git checkout ui_home_files_work
./gradlew :app:testDebugUnitTest
./gradlew :app:assembleDebug
# APK → app/build/outputs/apk/debug/app-debug.apk
```

Set the PC address in `app/.../core/Config.java` (`HOST` / `PORT`) before Transfer tests.

---

## What the app does now

| Tab | Role |
|-----|------|
| **Home** | Storage summary (C++ Action 7), shortcuts into other tabs |
| **Files** | Browse, search (C++), create/rename/delete, open image/video/document |
| **Storage** | Stats + category bars, large-file scan (C++ Action 9), delete to free space |
| **Transfer** | Test link to WayerPC, download (`/ask`) / upload (`/upload`) via Java sockets |

**Architecture idea**

- **Java + XML** → UI, navigation, sockets to PC  
- **C++ (JNI)** → heavy local work (list, search, storage stats, large files) via bulk JSON  
- **Networking** stays on the Java side (`NetworkManager`)

---

## Project layout (high level)

```text
Wayer/
├── app/                    # Android application (UI + Java)
│   └── src/main/
│       ├── java/.../wayer/
│       │   ├── core/       # MainActivity, NativeEngine, Config
│       │   ├── ui/         # Fragments, viewers, FileAdapter
│       │   ├── network/    # Hotspot protocol to WayerPC
│       │   ├── storage/    # FileMutator, StorageController
│       │   └── transfer/
│       └── res/            # Layouts, menus, vectors, themes
├── native/                 # C++23 engine (storage, transfer, documents)
│   └── third_party/        # Local external libs (gitignored)
├── docs/                   # Learning / feature documentation
├── gradle.properties       # versionCode, versionName, ABI list
└── .github/workflows/      # Unit-test CI
```

---

## Build notes

| Topic | Where |
|-------|--------|
| Version / multi-ABI / signing | [docs/RELEASE_AND_BUILD.md](docs/RELEASE_AND_BUILD.md) |
| Unit tests + how to add more | [docs/TESTING.md](docs/TESTING.md) |
| Icons | [docs/ICONS.md](docs/ICONS.md) |

Default native ABIs (edit `aurora.abiFilters` in `gradle.properties`):

```text
arm64-v8a, armeabi-v7a, x86_64
```

---

## Related

- PC server work: other branches / `pc-end` as you maintain them  
- Document rendering (PDF, etc.): foundation only — libs go under `native/third_party/` when ready  
