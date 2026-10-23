# Wayer (Android) — Odin + C wrappers + Material 3 · October 2025

Android client for browsing local storage and transferring files with **WayerPC** over a phone hotspot. This branch (`arena/e58556e6-wayer`) is the **October 2025 Odin rewrite**: native logic in Odin (`native/*/src/*.odin`) with bionic-safe C wrappers (`native/core/src/android_fs.c`, `index_c.c`), targeting **Android 10 (API 29)**.

> **Toolchain** · Odin `dev-2025-10` (monthly) + Android NDK 29.x + CMake 3.22.1 · ABI `arm64-v8a` only (covers phones from ~2017; see `gradle.properties`). The old C++ modules remain and link beside Odin so the app works before every `.cpp` is ported.

| Doc | Purpose |
|-----|---------|
| [README_ANDROID_END.md](README_ANDROID_END.md) | Full Android setup, structure, usage |
| [docs/BRIDGE_PLAN.md](docs/BRIDGE_PLAN.md) | Java ↔ native file-backed bridge (7 steps) |
| [docs/FRONTEND_IMPROVEMENTS.md](docs/FRONTEND_IMPROVEMENTS.md) | **New** · UI/UX refresh: Material 3, icons, radii, nav |
| [docs/NATIVE_OVERVIEW.md](docs/NATIVE_OVERVIEW.md) | **New** · Native sweep: Odin syntax, C wrappers, bionic notes |
| [docs/TRANSFER_CLEANER_PLAN.md](docs/TRANSFER_CLEANER_PLAN.md) | Transfer + Cleaner rework plan |
| [native/MODULES.md](native/MODULES.md) | Native modular layout + dependency graph |
| [docs/XML_UI_GUIDE.md](docs/XML_UI_GUIDE.md) | XML UI building blocks (updated) |
| [docs/ADB_GUIDE.md](docs/ADB_GUIDE.md) | Install, logcat, inspect via adb |

---

## Quick start

```bash
# Requires Odin dev-2025-10 on PATH: https://odin-lang.org/docs/install/
odin version          # → dev-2025-10 (OCT 2025) or newer
./gradlew :app:testDebugUnitTest
./gradlew :app:assembleDebug
# APK → app/build/outputs/apk/debug/app-debug.apk
```

Set the PC address in `app/.../core/Config.java` (`HOST` / `PORT`) before Transfer tests.

### Odin build (what Gradle does)

```
native/CMakeLists.txt → discovers all *.odin under native/ (GLOB_RECURSE + CONFIGURE_DEPENDS)
                     → `odin build native/odin -build-mode:obj -target:linux_arm64 -subtarget:android`
                     → packs .o → libwayer_core_odin.a (via NDK llvm-ar)
                     → jni/ links it + C++ modules + C wrappers into libwayer_engine.so
```

Add a new `.odin` file anywhere under `native/` and import it from an already-imported package (e.g. `wayer_core.odin`) — CMake notices it on next configure, no CMake edit needed.

---

## What the app does now

| Tab | Role |
|-----|------|
| **Home** | Recent files by day (from `BUILD_INDEX` → `GROUP_INDEX_BY_DAY`), storage summary, shortcuts |
| **Files** | Browse (remembers folder + Up), live search (C walk), create/rename/delete, open image/video/document, FAB for new folder |
| **Storage** | Storage stats (statvfs + walk → file-backed snapshot), category bars, refresh forces recompute |
| **Transfer** | Guide / Transfer / Search / Browse / Network tabs; multi-select queue, one-by-one upload, session UI |
| **Cleaner** | Utility card grid + sideways tabs: Duplicates (3-stage FNV-1a + byte verify), Large files (sorted) |
| **Internals** | Read-only browser of the private app home (index, cache, logs, manifest) |

**Architecture**

- **Java + XML** → UI (Material 3), navigation (NavigationBarView), sockets to PC
- **`bridge/` package** → single doorway to native: path registry, leases, result-path cache
- **Odin (primary) + C wrappers** → computes into files under the private app home (`files/wayer/`); JNI carries only `{status, path}`
  - `native/core/src/` → `core_heart` (AppPaths, logging, json_escape, ascii_lower)
  - `native/storage/src/` → `storage` (walker, stats, search, cleaner, organizer, index bridge)
  - `native/documents|transfer|preview|media` → their respective Odin packages
  - `native/core/src/android_fs.c` → bionic-safe FS (opendir/readdir/stat only, no statx — required for Android 10 seccomp)
  - `native/storage/src/index_c.c` → file-backed index + streaming parser (heap GroupUd, not stack)
- **Networking** stays on Java side (`NetworkManager`)
- **C++ shim** (`native/shim/wayer_shim.cpp`) remains linking until fully replaced by Odin exports in `native/odin/wayer_core.odin`

---

## Project layout (high level)

```text
Wayer/
├── app/                    # Android application (UI + Java)
│   └── src/main/
│       ├── java/.../wayer/
│       │   ├── bridge/     # NativeEngine, Bridge, PathRegistry, leases, caches
│       │   ├── core/       # MainActivity (NavigationBarView), Config, theme/blur/chrome
│       │   ├── ui/         # Fragments, viewers, adapters (Material 3, icons)
│       │   ├── network/    # Hotspot protocol to WayerPC
│       │   ├── storage/    # FileMutator, FileIndexer (paths), OrganizeHelper
│       │   └── transfer/   # Controllers, upload queue
│       └── res/            # Layouts, menus, vectors, themes, strings
│           ├── values/            colors (solid surfaces) + dimens (reduced radii) + themes (elevation)
│           ├── layout/            activity_main (NavigationBarView), fragments, items
│           ├── drawable/          distinct nav icons + action icons
│           └── menu/              menu_bottom_nav.xml (6 destinations)
├── native/                 # Native modules: C + C++ + Odin (Oct 2025)
│   ├── CMakeLists.txt      # orchestrates modules → Odin archive → libwayer_engine.so
│   ├── odin/               # wayer_core.odin (router + C ABI exports)
│   ├── core/               # wayer_core (paths, logging, json, text) — Odin + C
│   │   ├── include/wayer/core/android_fs.h  # bionic allowlist header
│   │   └── src/            # *.odin (documented) + android_fs.c
│   ├── storage/            # wayer_storage — largest module
│   │   ├── src/            # analyser, cache, search, cleaner, organizer, walker, etc. (*.odin)
│   │   ├── src/index_c.c   # file-backed index (STREAM, GROUP)
│   │   └── modules/cleaner|search|organizer
│   ├── documents/          # wayer_documents
│   ├── transfer/           # wayer_transfer
│   ├── media/              # wayer_media (stub, future thumbs/metadata)
│   ├── preview/            # wayer_preview (capped text preview)
│   ├── jni/                # JNI boundary (wayer_engine.c — thin router)
│   ├── shim/               # wayer_shim.cpp + odin_bionic_shim.h (C wrappers docs)
│   └── third_party/        # nlohmann/json + SQLite (gitignored)
├── docs/                   # Guides + new NATIVE_OVERVIEW + FRONTEND_IMPROVEMENTS
├── gradle.properties       # versionCode, versionName, ABI list (arm64-v8a only on this branch)
└── .github/workflows/      # Unit-test CI
```

---

## Odin October 2025 — what changed in native/

**Compiler** `dev-2025-10` (see [Migrating to new core:os](https://odin-lang.org/news/moving-towards-a-new-core-os/) + newsletter):

- `core:os` v2 — new file APIs require explicit allocator, `^os.File` not `Handle`, streaming via `os.stream_from_handle`. **We do not use `core:os` for filesystem on Android** — all file I/O goes through `android_fs.c` C wrappers (see below) so seccomp on API 29 never sees `statx`/`openat2`.
- `using` as statement is now opt-in (`#+feature using-stmt`) — we don't use it.
- Dynamic literals (`map{}` literals) require `#+feature dynamic-literals` — we use `make(map[...])` to avoid it.
- `ODIN_OS == .Android` (enum) not `"android"` string; `foreign import "system:c"` + `@(default_calling_convention="c")` for libc calls.

**Target Android 10 (API 29)**

- **No `statx`** — `__builtin_statx` is blocked by seccomp on Android 10. Every walk/stat/open in Odin uses `wayer_fs_*` (from `android_fs.c`) which calls only `opendir`/`readdir`/`stat`/`open`/`read`/`write`/`mkdir`/`rename`/`unlink`. The header documents the allowlist.
- **File-backed replies** — large JSON never crosses JNI; native writes to `<filesDir>/wayer/cache/...`, JNI returns `{status, path}`, Java reads the file. Keeps JNI strings < 16 KiB and respects mobile memory limits (see `index_c.c` heap GroupUd note).
- **ABIs** — `arm64-v8a` only on this experiment branch (modern phones since 2017). Adding `armeabi-v7a`/`x86_64` is one line in `gradle.properties` + matching `linux_arm`/`linux_amd64` targets in `native/CMakeLists.txt`.

Full sweep log + C wrapper contract: **[docs/NATIVE_OVERVIEW.md](docs/NATIVE_OVERVIEW.md)** · Per-module comments in every `*.odin` header block.

---

## Frontend refresh (Material 3, Oct 2025)

**Problem** — too many rounded corners (16dp/24dp everywhere), glass strokes on every card, custom scrollable toggle bar for bottom nav (BottomNavigationView crashed at 5 items), duplicate folder icons for all nav destinations, weak empty states.

**Fix** — documented in **[docs/FRONTEND_IMPROVEMENTS.md](docs/FRONTEND_IMPROVEMENTS.md)**:

| Area | Before | After |
|------|--------|-------|
| Bottom nav | HorizontalScrollView + 120dp MaterialButtonToggleGroup | **NavigationBarView** (Material3, 6 items, active indicator, no scroll) |
| Surfaces | `wayer_surface` 80% translucent + 1dp `wayer_outline_glass` on every card | **Solid surfaces** (`#151A22` / `#FFFFFF`) + `2dp` elevation; stroke only on `Card.Outlined`; glass only for optional blur mode |
| Radii | `radius_md=16dp`, `radius_lg=24dp` on every card + list row | **Reduced**: rows `4dp` → cards `8dp` → hero `12dp` → sheets `16dp`; touch targets 48dp min |
| Icons | Same folder icon for all nav; text-only buttons | **Distinct vectors** per nav destination (house/folder/pie/arrows/sparkle/code) + action icons (search, up, refresh, download/upload) |
| Typography | Ad-hoc 28sp bold | Toolbar titles use `displaySmall` / `titleLarge`; body uses Material type scale |
| Empty states | Plain text | Icon + subtitle + action (FAB for new folder in Files) |
| Drawables | Gradient layer-list `bg_glass_panel` on every panel | Simple solid shapes; bg_glass_* only for blur mode |

See also [docs/XML_UI_GUIDE.md](docs/XML_UI_GUIDE.md) for the updated token map.

---

## Build notes

| Topic | Where |
|-------|--------|
| Version / ABI / signing | [docs/RELEASE_AND_BUILD.md](docs/RELEASE_AND_BUILD.md) |
| Unit tests + how to add more | [docs/TESTING.md](docs/TESTING.md) |
| Icons (new set) | [docs/ICONS.md](docs/ICONS.md) + [docs/FRONTEND_IMPROVEMENTS.md](docs/FRONTEND_IMPROVEMENTS.md) |
| Install / logcat / inspect | [docs/ADB_GUIDE.md](docs/ADB_GUIDE.md) |
| Native modules + Odin style | [native/MODULES.md](native/MODULES.md) + [docs/NATIVE_OVERVIEW.md](docs/NATIVE_OVERVIEW.md) |

Default ABI on this experiment branch (edit `aurora.abiFilters` in `gradle.properties`):

```text
arm64-v8a
```

Main branch ships `arm64-v8a, armeabi-v7a, x86_64`.

---

## Related

- PC server work: other branches / `pc-end` as you maintain them
- Document rendering (PDF, etc.): foundation only — libs go under `native/third_party/` when ready
- Odin package docs: `odin doc native/odin -file` + [odin-lang.org/docs](https://odin-lang.org/docs/)
