# Bridge plan: file-backed Java ↔ C++ (step by step)

Status: plan only — implemented one step at a time, each verified on device.
Vision owner: you. This file is the shared checklist; check boxes as we land steps.

## Vision (what we are building)

Today Java and C++ talk in JSON strings over JNI. Tomorrow they talk in
**files**: Java hands C++ a path, C++ writes its result there, Java reads the
file when it needs the data. JNI carries only tiny status replies
(`ok` / `error` + a path). Nothing big ever crosses the boundary, and nothing
big sits in memory — the phone's storage is the shared memory.

Concretely:

- The private home (`files/wayer/`, proven on device) holds a `paths.json`
  manifest plus per-module processing folders.
- A Java **bridge** owns all storage access: path registry, result-path cache
  (new + old), and leases so two jobs never write the same file at once
  (e.g. a refresh while a search reads the index).
- C++ receives a path, does exactly what it is told, writes the output file,
  returns success/failure. Reused for search, stats, index, organize.
- Stats will outgrow hand-written JSON (per-app, per-folder breakdowns) —
  that is when the first real C++ libs land: a JSON lib and SQLite.

## Ground rules (what does NOT change)

1. UI fragments keep their current method names; only the bodies re-point.
2. `native/jni/wayer_engine.cpp` stays a thin router — one `processAction`.
3. All native file work stays serialized on one background executor
   (already true today via the single-thread executor — the bridge keeps it).
4. Private internals stay private (`getFilesDir()`); only explicit user files
   go to shared storage (see `docs/STORAGE_AND_TRANSFER.md`).
5. C++ style stays beginner-readable (see `native/MODULES.md` style rules).

---

## Step 0 — Vendor the first C++ libs (you run this, guidance below)

**Exit:** `native/third_party/{json,sqlite}/` present locally (gitignored),
both compile in a host test. No app behavior change.

Why these two, in this order:

| Lib | Job | Shape | License |
|-----|-----|-------|---------|
| nlohmann/json | Replace hand-`format` JSON where payloads nest (stats first) | **one header** `json.hpp` | MIT |
| SQLite | Structured results (per-app / per-folder stats, index metadata) | **amalgamation**: `sqlite3.h` + `sqlite3.c` | public domain |

Target layout (binaries/trees stay uncommitted per `.gitignore`):

```text
native/third_party/
  README.md
  json/include/nlohmann/json.hpp
  sqlite/sqlite3.h
  sqlite/sqlite3.c
```

### 0a. nlohmann/json (single header)

Pick a version from https://github.com/nlohmann/json/releases
(example: `v3.11.3`). Download **only** the `json.hpp` asset:

```powershell
New-Item -ItemType Directory -Force native/third_party/json/include/nlohmann
Invoke-WebRequest `
  -Uri "https://github.com/nlohmann/json/releases/download/v3.11.3/json.hpp" `
  -OutFile "native/third_party/json/include/nlohmann/json.hpp"
```

Sanity: the file is ~900 KB, starts with `#pragma once`, contains `NLOHMANN_JSON_VERSION_MAJOR`.

### 0b. SQLite amalgamation

Open https://sqlite.org/download.html, take the current
`sqlite-amalgamation-*.zip` (C source, not the DLL), unzip **only**
`sqlite3.h` and `sqlite3.c` into `native/third_party/sqlite/`:

```powershell
New-Item -ItemType Directory -Force native/third_party/sqlite
# unzip sqlite-amalgamation-*.zip somewhere temp, then:
Copy-Item <temp>/sqlite-amalgamation-*/sqlite3.h native/third_party/sqlite/
Copy-Item <temp>/sqlite-amalgamation-*/sqlite3.c native/third_party/sqlite/
```

Sanity: `sqlite3.h` starts with `#ifndef SQLITE3_H_INCLUDED`; the page
lists SHA3 sums — compare if you want to be thorough.

### 0c. CMake wiring (I do this in the code step)

```cmake
# header-only: include dir only, no compile
add_library(wayer_json INTERFACE)
target_include_directories(wayer_json INTERFACE ${CMAKE_CURRENT_SOURCE_DIR}/third_party/json/include)

# amalgamation: compiled once into a static lib.
# NOTE: deliberately NOT linked to project_warnings — the 8 MB C file
# would drown us in third-party warnings. Our flags stay on our code.
add_library(wayer_sqlite3 STATIC third_party/sqlite/sqlite3.c)
```

Modules opt in with `target_link_libraries(... PRIVATE wayer_json)` /
(`... wayer_sqlite3`) only where they need it. First consumer: stats
output (Step 5). `std::format`-built JSON stays where payloads are flat —
we do not rewrite working code for fashion.

---

## Step 1 — Bridge package skeleton (Java only, no behavior change)

**Exit:** new package `com.example.wayer.bridge/` compiles; app behaves
identically; `MainActivity` + fragments call the same methods.

- Move `core/NativeEngine.java` → `bridge/NativeEngine.java` (same class,
  new home; JNI entry names don't care about Java packages — only the class
  name string in `wayer_engine.cpp` matters, so this move renames the JNI
  functions too — do it as one atomic rename + rebuild + launch check).
- New `bridge/Bridge.java`: owns the background executor (moved out of
  `NativeEngine`), exposes `run(actionId, payload, callback)`. All future
  file-aware calls go through here; raw `processActionAsync` stays for now.
- Move `storage/AppDirs.java`, `storage/NativeCache.java`,
  `storage/StorageCapacity.java` → `bridge/` unchanged (imports updated).
- Verify: `assembleDebug` + install + tap through every tab.

## Step 2 — Path registry + module scratch folders

**Exit:** any Java code can ask the bridge for `cacheDir()`, `tempDir()`,
`logsDir()`, `moduleDir("search")` and get verified paths; `paths.json`
is the single source (no more re-derived paths on the Java side).

- New `bridge/PathRegistry.java`: loads the manifest Java saved at init
  (`initAppPathsAsync` response → persist `manifest` path + inline fallback),
  getters create module scratch dirs (`<root>/modules/<name>/`) on demand.
- Native already writes the manifest; this step only teaches Java to read it.
- Verify on device: Internals tab shows `paths.json`; registry paths match it.

## Step 3 — Leases (one writer per file)

**Exit:** refresh-while-searching no longer risks a torn read; lease table
is in-memory, per process, with timeouts.

- New `bridge/FileLeases.java`: `acquire(path, owner, timeoutMs)`,
  `release(path)`, `isFree(path)`. Stale leases expire; every acquire/release
  logged at debug level.
- `Bridge.run` takes an optional lease key; refresh/search flows pass theirs.
- Verify: start a search, hit refresh mid-way, confirm no crash/stale mix.

## Step 4 — Search results go to files

**Exit:** `SEARCH_FILES` / `SEARCH_INDEX` / `FIND_DUPLICATES` return
`{status, path, count}`; Java reads the result file; memory stays flat.

- C++ writes matches to `<moduleDir>/results-<job>.json`, returns the path.
- Java `PathCache` remembers new + previous result path per job key so the
  UI can show the old list while the new one builds.
- `FileIndexer` / `FileSearcher` bodies re-point; method names unchanged.
- Verify: large-tree search, rotate phone mid-search, old list survives.

## Step 5 — Stats grow up (JSON lib + SQLite arrive)

**Exit:** stats snapshot is a real JSON document (json lib) with per-folder
detail; SQLite file created (schema v1) but only stats use it at first.

- `get_storage_stats(root, out_path, known_device_bytes)` writes the file,
  returns status only. Per-app / per-folder breakdowns become tables, not
  string surgery.
- Java reads the file for the Storage/Home screens (same UI, new source).
- Verify: Storage screen numbers identical to Step 4 build, file present in
  Internals browser.

## Step 6 — Create/delete through the bridge

**Exit:** every mutation goes `Bridge → lease → C++ → status`; Java pre-creates
output files and hands paths in; `FileMutator`/`OrganizeHelper` delegate.

- New actions take explicit in/out paths; C++ never invents locations.
- `apply_organize` pipe format dies here, replaced by a job file.
- Verify: plan → apply → Internals shows moved files, stats refresh clean.

## Step 7 — Refreshable whole-storage index (the loop closes)

**Exit:** Refresh button rebuilds the index file under lease; every
recursive search reads the index file, never walks live storage.

- `BUILD_INDEX(root, out_path)` + `INDEX_META` + `SEARCH_INDEX` all
  file-backed; `FileIndexer.refreshCache()` becomes a bridge call.
- Transfer/Files share the one index (the facade pattern from
  `FUTURE_JNI_AND_CPP23.md`, finally wired).
- Verify: airplane-mode airplane test — index searches work fully offline
  from the file; refresh updates `modified_unix`.

---

## Protocol (applies from Step 4 on)

- Java → C++: plain strings + explicit file paths. Java creates parent dirs
  first; C++ may assume the out-path's parent exists (and must still fail
  cleanly with `{"status":"error","reason":"..."}` if it doesn't).
- C++ → Java: `{"status":"ok","path":"..."}` or
  `{"status":"error","reason":"..."}`. Nothing else crosses JNI.
- One executor, one file access at a time; leases guard the rest.

### Two-path calls (source in, result out)

Wherever a job has an input artifact and an output artifact, Java passes
**both paths** and C++ fills the output:

```text
in_path   = file C++ must read  (index file, plan file, source root listing…)
out_path  = file C++ must write (results, snapshot, report…)
payload   = in_path|out_path|params…
response  = {"status":"ok","path":"<out_path>"}  (never the content itself)
```

Java may pre-create the out file (even empty) inside local storage and hand
it over; C++ truncates and writes it, then Java reads it. Examples:

| Job | in_path | out_path |
|-----|---------|----------|
| index search | `cache/index/files.json` | `modules/search/results-<job>.json` |
| storage stats | (root passed as plain string) | `cache/stats/snapshot.json` |
| apply organize | `temp/plan-<job>.json` (replaces the pipe format) | `temp/report-<job>.json` |
| text preview | target file itself | n/a (small capped content still returned inline) |

Small capped reads (preview, meta) keep returning inline content — files are
for results that can grow, not for ceremony.

### Special instructions (reserved for later)

Some calls will carry an instruction word alongside paths — e.g. "search
only inside this folder", or a future custom algorithm selector. For now we
only **strengthen the underlying mechanism** (paths in, files out, status
back); no custom algos yet. When they come, they arrive as one extra payload
field, never as new JNI crossings.

## JNI consolidation (the switch statement will shrink)

Redundant actions merge as their flows go file-backed. Direction of travel:

| Today | Becomes |
|-------|---------|
| 8 `SEARCH_FILES` (live walk) + 18 `SEARCH_INDEX` (index search) | **one** search entry in `wayer_storage`; transfer search and Files search call the **same** C++ function — same query may name an index file *or* a root, the module decides the walk |
| 7 `STATS` + 13 `CACHED_STATS` | **one** stats-to-file entry (`root\|out_path[\|bytes]`) |
| 9 `FIND_LARGE`, 10 `FIND_DUPLICATES` | file-out variants under the same cleaner module |
| 11 `PLAN_ORGANIZE`, 12 `APPLY_ORGANIZE` | plan file in, report file out (pipe format retired) |
| 1 `PING`, 2 `STATUS`, 3 `LIST`, 4 `NET_INFO`, 5 `FILTER_DOCS`, 6 `LISTENER` | keep as-is (tiny answers, no files needed) |
| 14 `INIT`, 15 `BUILD_INDEX`, 16 `INVALIDATE`, 17 `INDEX_META`, 19 `READ_TEXT` | keep (already file-shaped) |

Rule: searches that differ only in *caller* (transfer vs Files) share one C++
implementation; searches that differ in *algorithm* still live in the same
module side by side. The exact renumbered action set is frozen per step
(Steps 4–7), never in one big-bang edit.

## File map (where today's code lands)

| Today | Destination |
|-------|-------------|
| `core/NativeEngine.java` | `bridge/NativeEngine.java` (thin JNI, unchanged logic) |
| executor in `NativeEngine` | `bridge/Bridge.java` (owns threading + leases) |
| `storage/AppDirs.java` | `bridge/` (path policy, unchanged) |
| `storage/NativeCache.java` | absorbed into `bridge/PathCache.java` |
| `storage/StorageCapacity.java` | `bridge/` (unchanged) |
| `storage/PathRegistry.java` | **new** (Step 2) |
| `storage/FileLeases.java` | **new** as `bridge/FileLeases.java` (Step 3) |
| `storage/FileIndexer.java`, `FileSearcher.java` | re-pointed, same names (Steps 4, 7) |
| `storage/FileMutator.java`, `OrganizeHelper.java` | delegate to bridge (Step 6) |
| `storage/StorageController.java`, `StorageItem.java`, `FileNavigator.java`, `FolderSkipController.java` | unchanged until their step needs them |
| fragments (`ui/*`) | method names stable; bodies re-point per step |

## How we work this file

One step per change, each ending in `assembleDebug` + install + tap-through.
Check the step's box above only after the device confirms it. If a step
fights back, we split it — never stack step N+1 on an unverified step N.
