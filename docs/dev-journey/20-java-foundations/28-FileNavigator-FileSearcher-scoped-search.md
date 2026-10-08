# 28 — `FileNavigator` + `FileSearcher` + `StorageController` (scoped world)

## Goal
Separate scoped browsing (Files) from global index (Transfer) — stop mixing them.

## Touches
- `app/src/main/java/com/example/wayer/storage/FileNavigator.java`, `storage/FileSearcher.java`, `storage/StorageController.java`, `storage/StorageItem.java`, `storage/FolderSkipController.java`
- Native: `SEARCH_FILES` (live scoped) vs `SEARCH_INDEX` (global), `storage/modules/search/src/file_search.cpp`
- UI: `ui/FilesFragment.java`, `ui/TransferFragment.java` (Search tab)

## How it works today
- `FileNavigator`: list ONE folder via `java.io` (folders never needed index), remembers path via `BrowseSession`.
- `FileSearcher`: scoped live search in current folder via native `SEARCH_FILES` (finds just-created files).
- `StorageController`/`StorageItem`: stats-driven rows; `FolderSkipController`: skip rules for storage rollups.
- Transfer global search uses `SEARCH_INDEX` on shared index file (meta-gated rebuild).

## Guided tasks
1. Read all three helpers. For each method note: `java.io` vs native, scoped vs global, fresh vs cached.
2. Trace Files search (scoped) vs Transfer Search tab (index) side by side. Write the freshness table.
3. Improvement: `FolderSkipController` — audit skip list vs `safety.hpp` exclusions. Unify or document divergence.
4. Fix ONE papercut: Files search debouncing? Empty-query behavior? Rapid-typing busy handling (single-retry)? Pick one, implement.

## Stretch
- Unified query box that tries scoped first, offers "search whole storage (may be stale)" fallback link. UX sketch + payload design.

## Verify
- [ ] Files scoped search finds just-created file; Transfer index search documented stale-until-refresh.
