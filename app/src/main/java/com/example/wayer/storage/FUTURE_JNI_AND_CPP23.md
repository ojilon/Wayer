# Future: FileIndexer / search → C++ & lower JNI cost

Keep Java UI functional (OOP where required). Deeper storage layers should stay more functional and eventually move hot paths into native.

## Current split

| Concern | Today | Target |
|---------|--------|--------|
| Folder walk / index | `FileIndexer` (Java) | C++ `storage_engine` + bulk JSON once |
| Keyword search | Java flat lists | C++23 ranges / parallel algorithms over native index |
| List dir / large files | JNI action 3 / 9 | Keep; batch results, fewer round-trips |
| Mutations | `FileMutator` Java | Optional native later; UI stays Java |

## Reduce JNI crossing cost

1. **Batch, don’t chat** — one `processAction` returning a large JSON (or protobuf later) beats many small calls.
2. **Avoid string thrash** — prefer fixed action IDs + single payload string; consider direct `ByteBuffer` / critical JNI arrays for binary later.
3. **Cache on native side** — rebuild index in C++; Java holds only a thin facade (or SharedPreferences path for “last save folder”).
4. **Async only on boundary** — `NativeEngine.processActionAsync` already isolates the hop; keep UI callbacks on main thread only.

## C++23 usage (when touching `native/storage`)

- `std::filesystem` for walks (already aligned with engine style).
- `std::ranges` / views for filter/map of paths.
- `std::jthread` or a fixed worker pool for index rebuild without blocking JNI attach.
- Structured bindings and `std::optional` for cleaner parse of path components.
- Prefer `std::string_view` at API edges inside C++; convert to jstring only at the JNI boundary.

## Suggested migration steps (do not rush)

1. Expose action e.g. `10 = REBUILD_INDEX`, `11 = SEARCH_INDEX` returning the same JSON shape Files already expects.
2. Point `FileIndexer` methods at those actions (facade) while keeping the Java cache as fallback.
3. Delete duplicate Java walk once native path is stable on device storage permissions.
4. Wire Transfer upload search to the same native search so Files and Transfer share one index.

No serious Java architecture rewrite required for the above — only replace the body of search/index calls.
