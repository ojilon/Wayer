# Future JNI boundary & C++23 (Wayer native)

Notes for improving the Java ↔ C++ relationship without a big-bang rewrite.

## Principles

- **UI stays Java** (Fragments, adapters, Material). OOP is unavoidable on the UI side.
- **Hot paths → C++**: walk, search, stats, media metadata, transfer framing helpers.
- **Fewer crossings**: each JNI hop costs; design for bulk JSON (or later binary) replies.

## Reduce JNI cost

| Technique | Why |
|-----------|-----|
| Single action + payload | One `processAction(id, payload)` vs many natives |
| Large result blobs | List/search/stats already return JSON once |
| Background executor on Java | `NativeEngine` already off-main; keep it |
| Avoid per-file JNI | Never call native once per path in a loop |
| Critical / direct buffers (later) | For file bytes if protocol moves partially native |

Sockets/hotspot protocol remain **Java** (`NetworkManager`) by project rule; native can still hash/verify or compress offline.

## More C++23 in this tree

- Enable/keep `-std=c++23` in CMake (already in app `externalNativeBuild`).
- Prefer `std::filesystem`, ranges, `string_view`, `optional`, `expected`-style error returns inside engines.
- Document each new action ID in `docs/STORAGE_AND_TRANSFER.md` when added.

## Action ID roadmap

| ID | Name | Notes |
|----|------|--------|
| 3 | LIST_FILES | exists |
| 6 | START_LISTENER | exists |
| 7 | STORAGE_STATS | retired — merged into 13 (file-backed) |
| 8 | SEARCH_FILES | file-out (`root\|out\|query…`) |
| 9 | FIND_LARGE | exists |
| 10 | FIND_DUPLICATES | exists |
| 11 | PLAN_ORGANIZE | file-out (`root\|out`) |
| 12 | APPLY_ORGANIZE | file-in/out (`plan\|report`, JSON via lib) |
| 13 | GET_CACHED_STATS | file-backed (`cache\|root\|max_age[\|bytes]` → `{status,path}`; max_age ≤ 0 forces recompute) |
| 14 | INIT_APP_PATHS | exists — Java passes files dir once |
| 15 | BUILD_INDEX | exists — writes `cache/index/files.json`, returns `{path, count}` |
| 16 | INVALIDATE_CACHE | exists — drops a cache file after mutations |
| 17 | INDEX_META | exists — `{status, path, bytes, modified_unix}`, never the listing |
| 18 | SEARCH_INDEX | exists — substring search over the index file, capped matches |
| 19 | READ_TEXT_FILE | exists — read-only text preview (`path\|max_bytes`), binary refused |

## Facade pattern (landed as Step 7, leaner than planned)

Instead of wrapping the Java walk, Step 7 deleted it: Transfer reads the
shared native index (`BUILD_INDEX` / `SEARCH_INDEX`) directly, and Files
keeps its scoped live search in the same native module. No parallel
implementations remain — one index file, one module, honest freshness rules
per screen (see `docs/BRIDGE_PLAN.md` Step 7).
