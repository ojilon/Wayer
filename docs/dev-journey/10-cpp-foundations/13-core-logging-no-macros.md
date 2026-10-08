# 13 — Logging without macros (`wayer::core::log`)

## Goal
Use the one logging path; keep release logs quiet and useful.

## Touches
- `native/core/include/wayer/core/logging.hpp`, `native/core/src/logging.cpp`
- `native/cmake/CompilerFlags.cmake`, `native/MODULES.md:84`
- Java side: `adb logcat -s WayerBridge` (see `docs/ADB_GUIDE.md`)

## How it works today
- No macros for logging. `wayer::core::log(...)` function; JNI boundary translates to
  `__android_log_print` where needed; host builds print to stderr.
- Warnings-as-errors for OUR code (`project_warnings`); third_party excluded deliberately.

## Guided tasks
1. Read `logging.hpp/cpp`. Note levels (debug/info/warn/error?) and thread-safety.
2. Add a log line to `walker.cpp` skip-branch (behind debug level only). Verify via logcat, then REMOVE it (keep tree quiet).
3. Improvement: add a `log_once` helper for noisy walks? Or rate-limit? Propose API in header comment.
4. Audit: grep for `printf`/`cout` in `native/` — replace strays with `core::log`.

## Stretch
- Design log-to-file: ring buffer in `logs/engine.log`, capped, viewable in Internals.

## Verify
- [ ] `assembleDebug` green with warnings-as-errors; logcat shows your debug line once.
