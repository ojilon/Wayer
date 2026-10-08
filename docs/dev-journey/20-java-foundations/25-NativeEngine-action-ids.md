# 25 — `NativeEngine`: ACTION ids + `*Async` wrappers (the contract table)

## Goal
Treat this file as the API table. Never guess payload formats.

## Touches
- `app/src/main/java/com/example/wayer/bridge/NativeEngine.java:5-122`
- `native/jni/wayer_engine.cpp` (each `case`), `docs/BRIDGE_PLAN.md:239-270` (protocol)

## How it works today
- `ACTION_PING=1 ... ACTION_READ_TEXT_FILE=19`. Each `*Async` builds `payload` (`a|b|c` pipes), calls `Bridge.run(action,payload,outPath,job,cb)`.
- Protocol: Java->C++ plain strings + explicit paths (Java creates parents first); C++->Java `{status,path}` or `{status:error,reason}`. Small reads inline, big results via files.
- `Two-path calls`: `in_path|out_path|params` (index file in, results out; plan in, report out).

## Guided tasks
1. Build the table: ACTION -> payload format -> C++ fn -> out file -> Java parse site. Put it in your PR description once — reviewers love it.
2. Find the WORST-documented `*Async` (missing null-guards? `root != null ? root : ""`?). Harden ONE with `TextUtils.isEmpty` + early `onResult(error)` without JNI.
3. Drill: spec a NEW action (`LIST_EMPTY_FOLDERS=20`, `root|out`) — write Java wrapper + payload + expected response BEFORE touching C++. (Implement in `30/` empty-folders case.)

## Stretch
- Deprecation plan: which actions merge per BRIDGE_PLAN §JNI consolidation? Draft renumber table WITHOUT applying.

## Verify
- [ ] Table matches `wayer_engine.cpp` cases 1:1; no orphan ACTION.
