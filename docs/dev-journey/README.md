# Dev Journey — sweep the codebase and ship improvements (1–2 months)

You asked for a serious, file-by-file guided tour: one md per case, each tracing
everything it touches, each ending in something you can build yourself.
This folder is that tour.

## How to use

1. Read in order: `00-orientation/` -> `10-cpp-foundations/` -> `20-java-foundations/`
   -> `30-cleaner/` -> `50-file-viewing/` -> `60-transfer/` -> `70-files-storage-ui/`
   -> `80-zig/` -> `90-system-design/` -> `100-libs/`.
2. One file = one sitting (45–90 min). Each file has: Goal, Touches (exact files),
   How-it-works-today, Guided tasks (do these in order), Stretch, Verify.
3. Code while you read. Don't just read 10 files then code — read 1, change 1 thing,
   build, commit.
4. Suggested pace: 1–2 files/day = ~6–8 weeks for all ~75 files.

## Where to start if you are weak on OOP/Android/XML/C++

- C++ first: `10-cpp-foundations/10-core-text-*.md` -> `14-extension-map` ->
  `15-walker` -> `17-preview` -> `large-files`. No classes, no inheritance.
- Java second: `20-java-foundations/20-TextSanitizer` -> `21-FileMutator` (+ its unit
  test) -> `22-FileIndexer` -> `24-OrganizeHelper`. Pure functions before Fragments.
- Avoid until comfortable: `Bridge.java`, `Fragments`, `wayer_engine.cpp` JNI,
  `NetworkManager.java`, sockets.

## About your git question

> "If I switch to main after merging this branch, will git give main these docs too (locally)?"

Yes — if you merge this docs branch INTO main locally, main then contains the files.
Steps (see `00-orientation/02-git-branches-PRs-and-main.md` for full guide):

```powershell
git checkout -b docs/dev-journey
# ... commit these md files, push, open PR, merge on GitHub ...
git checkout main
git pull origin main   # <-- this brings the merged docs into your local main
```

Until you `pull`/merge, local main won't have them. Branches don't auto-sync.

## Map

| Folder | What | Count |
|---|---|---|
| `00-orientation/` | repo map, tracing recipe, build/test loop, git | 5 |
| `10-cpp-foundations/` | core, extension_map, walker, safety, preview, JNI | 9 |
| `20-java-foundations/` | TextSanitizer, FileMutator, Indexer, Adapter, bridge | 9 |
| `30-cleaner/` | duplicates realistic, trash, auto-scan, notifications | 12 |
| `50-file-viewing/` | read/render/photo/video/types/paths/move/copy | 8 |
| `60-transfer/` | queue, protocol, PC-server guesses, unique ideas | 9 |
| `70-files-storage-ui/` | Files rethink, storage sense, icons, modern XML | 9 |
| `80-zig/` | CMake entry, small utils, practices, tooling | 5 |
| `90-system-design/` | when to go read, index/search/hash/schedule designs | 7 |
| `100-libs/` | vendoring, json/sqlite, thumbnails, pdf, compress | 5 |

Total: ~78 files. Each file names exact source paths — open them side by side.
Build loop is always: `./gradlew :app:testDebugUnitTest`, `./gradlew :app:assembleDebug`.
