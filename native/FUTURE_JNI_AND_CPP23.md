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

## Action ID roadmap (proposal)

| ID | Name | Notes |
|----|------|--------|
| 3 | LIST_FILES | exists |
| 6 | START_LISTENER | exists |
| 7 | STORAGE_STATS | exists |
| 8 | SEARCH_FILES | exists |
| 9 | FIND_LARGE | exists |
| 10 | REBUILD_INDEX | move FileIndexer walk here |
| 11 | SEARCH_INDEX | global name search over native cache |

## Facade pattern

Java `FileIndexer` can become a thin wrapper calling actions 10/11 so Transfer/Files keep stable APIs while the implementation shifts.
