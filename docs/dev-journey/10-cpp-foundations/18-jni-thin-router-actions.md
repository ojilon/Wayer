# 18 — `jni/wayer_engine.cpp`: the thin router (read, don't fatten)

## Goal
Know the ONLY JNI file, keep it thin, add actions correctly.

## Touches
- `native/jni/wayer_engine.cpp`, `native/jni/CMakeLists.txt`
- Java: `bridge/NativeEngine.java:5-32` (`ACTION_*` + `initEngine` + `processAction`)
- `docs/BRIDGE_PLAN.md:272-288` (JNI consolidation direction)

## How it works today
- One `processAction(actionId, payload)` switch. Parses `|`-separated payload (`root|out|params`), calls module fn, returns `{"status":...}` string. No `JNIEnv` outside `jni/`.
- Small answers (ping/status/list/meta/preview) inline; big answers via files.
- Consolidation plan: SEARCH_FILES+SEARCH_INDEX merge, STATS+CACHED_STATS merge, etc. — but one step at a time, never big-bang renumber.

## Guided tasks
1. Map every `ACTION_*` (1–19) to its C++ callee. Note which are file-backed (`*_to_file`) vs inline.
2. Add-action drill (dry run, no code): new `ACTION_LIST_EMPTY_FOLDERS=20` — write the payload format (`root|out_path`), response format, and which module owns it. Get the contract right BEFORE coding.
3. Hygiene: check for `reinterpret_cast` (only where OS forces, e.g. sockets), `static_cast` for narrowing, no business logic in JNI — just routing + string convert.
4. Read `CompilerFlags.cmake` — know warnings-as-errors; never silence third_party via our flags.

## Stretch
- Propose the merged search entry: one C++ fn taking `source = root-or-index-file`. Sketch signature + payload v2.

## Verify
- [ ] You can add a new ACTION end-to-end on paper (Java async + Bridge + JNI case + module fn + out file + parse).
