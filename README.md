# Wayer (Android)

Android client for browsing local storage and transferring files with **WayerPC** over a phone hotspot.

| Doc | Purpose |
|-----|---------|
| [README_ANDROID_END.md](README_ANDROID_END.md) | Full Android setup, structure, usage |
| [docs/BRIDGE_PLAN.md](docs/BRIDGE_PLAN.md) | Java ↔ C++ file-backed bridge plan (7 steps) |
| [docs/TRANSFER_CLEANER_PLAN.md](docs/TRANSFER_CLEANER_PLAN.md) | Transfer + Cleaner rework plan |
| [docs/CLEANER_IDEAS.md](docs/CLEANER_IDEAS.md) | Cleaner utility backlog |
| [docs/ADB_GUIDE.md](docs/ADB_GUIDE.md) | Install, logcat, inspect via adb |
| [docs/](docs/) | Feature guides (Home, Files, Storage, Transfer, tests, icons, XML) |

---

## Quick start

```bash
git checkout main
./gradlew :app:testDebugUnitTest
./gradlew :app:assembleDebug
# APK → app/build/outputs/apk/debug/app-debug.apk
```

Set the PC address in `app/.../core/Config.java` (`HOST` / `PORT`) before Transfer tests.

---

## What the app does now

| Tab | Role |
|-----|------|
| **Home** | Storage summary (shared snapshot file), shortcuts into other tabs |
| **Files** | Browse (remembers folder + Up), live search, create/rename/delete, open image/video/document |
| **Storage** | Stats summary + category bars, refresh forces recompute |
| **Transfer** | Guide / Transfer / Search / Browse / Network tabs; multi-select queue, one-by-one upload, session UI |
| **Cleaner** | Utility card grid + sideways tabs: Duplicates, Large files (more planned) |
| **Internals** | Read-only browser of the private app home (index, cache, logs, manifest) |

**Architecture idea**

- **Java + XML** → UI, navigation, sockets to PC
- **`bridge/` package** → single doorway to native: path registry, leases, result-path cache
- **C++ (JNI)** → computes into files under the private app home; JNI carries only `{status, path}`
- **Networking** stays on the Java side (`NetworkManager`)

---

## Project layout (high level)

```text
Wayer/
├── app/                    # Android application (UI + Java)
│   └── src/main/
│       ├── java/.../wayer/
│       │   ├── bridge/     # NativeEngine, Bridge, PathRegistry, leases, caches
│       │   ├── core/       # MainActivity, Config, theme/blur/chrome
│       │   ├── ui/         # Fragments, viewers, adapters
│       │   ├── network/    # Hotspot protocol to WayerPC
│       │   ├── storage/    # FileMutator, FileIndexer (paths), OrganizeHelper
│       │   └── transfer/   # Controllers, upload queue
│       └── res/            # Layouts, menus, vectors, themes, strings
├── native/                 # C++23 modules (core, storage, documents,
│                           transfer, media, preview) + JNI boundary in jni/
│   └── third_party/        # Local external libs: nlohmann/json, SQLite (gitignored)
├── docs/                   # Learning / feature / plan documentation
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
| Install / logcat / inspect on device | [docs/ADB_GUIDE.md](docs/ADB_GUIDE.md) |
| Native modules + C++ style | [native/MODULES.md](native/MODULES.md) |

Default native ABIs (edit `aurora.abiFilters` in `gradle.properties`):

```text
arm64-v8a, armeabi-v7a, x86_64
```

---

## Related

- PC server work: other branches / `pc-end` as you maintain them  
- Document rendering (PDF, etc.): foundation only — libs go under `native/third_party/` when ready  
