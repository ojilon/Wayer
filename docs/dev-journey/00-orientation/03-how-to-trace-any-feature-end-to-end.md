# 03 — How to trace any feature end to end (the recipe)

## Goal
Fix "reading and tracing is not direct, especially Java+OOP" with a repeatable recipe.

## The indirection problem
Fragments don't do work. They call helpers, which call `NativeEngine.*Async`,
which calls `Bridge.run(action, payload, callback)`, which calls JNI
`processAction`, which routes to a C++ function that writes a JSON FILE, which
Java then reads and parses. Objects you expect are files you must open.

## Recipe (use for every feature)
1. Start at the click: find `setOnClickListener` in `ui/*Fragment.java`.
2. Note the `NativeEngine.*Async` name + `ACTION_*` int.
3. Open `native/jni/wayer_engine.cpp`, find `case ACTION_*` — note C++ function.
4. Open that C++ `src/*.cpp` + its `include/wayer/**/*.hpp`.
5. Note the OUT file path (`PathRegistry.moduleDir(ctx,"...")` on Java side).
6. Find the callback: `PathCache.readFile(...)` + `new JSONObject(content)`.
7. Check `Internals` tab (`ui/InternalFragment.java`) — every file is browsable there.

## Worked example: Large-files card
- Click: `ui/CleanerFragment.java` (large-files strip button).
- Java: `NativeEngine.findLargeFilesAsync(root,minBytes,max,outPath,cb):85`.
- JNI: `ACTION_FIND_LARGE_FILES=9` -> `find_large_files_to_file`.
- C++: `native/storage/modules/cleaner/src/large_files.cpp:26,70`.
- Result: `modules/cleaner/results-<job>.json` -> parsed into list rows.
- Invalidate: `NativeCache.invalidateStatsSnapshot` after deletes.

## Guided tasks
1. Trace Duplicates the same way (`ACTION_FIND_DUPLICATES=10` ->
   `duplicate_finder.cpp:62`). Write the 6-step chain in your own words.
2. Trace Organize plan (`OrganizeHelper.requestPlan:34` -> `ACTION_PLAN_ORGANIZE=11`
   -> `file_organizer.cpp:55`).
3. Trace text preview (`ACTION_READ_TEXT_FILE=19` -> `preview/preview.cpp:24`).

## Verify
- [ ] You can trace any card without grep-hopping for >5 min.
