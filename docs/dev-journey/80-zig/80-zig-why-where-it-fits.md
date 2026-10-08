# 80 — Zig: why it fits THIS repo (and where it doesn't)

## Goal
Decide Zig's jobs before writing any Zig. Language carries good practices — use them deliberately.

## Touches
- `native/CMakeLists.txt`, `native/cmake/CompilerFlags.cmake`, `app/build.gradle` (`externalNativeBuild`)
- Candidates: build tooling, small utils (`ascii_lower`, `escape`, `date_bucket`), hash/compare, test runners
- NOT candidates (yet): JNI boundary (stay C++), SQLite/json internals, UI/Java

## Why Zig here
- **Explicit allocators** -> you SEE every allocation (vs hidden `std::string` copies in 10/11). Good teacher for the "where does memory go" question behind file-backed design.
- **Comptime** -> tables like `EXTENSION_MAP` (14) generated + verified at compile time, no runtime init order bugs.
- **`error` unions** -> `error_code`-style honesty (your C++ rule) enforced by compiler, not discipline.
- **Cross-compile + `zig cc`** -> host tests for native logic without NDK pain.
- **C interop** -> call your C++ `walk_files`/hash fns from Zig tests, or expose Zig fns as `extern "C"` to C++ — incremental, no rewrite.

## Where Zig does NOT go first
- JNI (`JNIEnv` + exceptions + lifecycle — C++ stays).
- Anything needing exceptions/RTTI (you don't use them anyway — good).
- Whole-module rewrites (never — one fn at a time, behind same header).

## Guided tasks
1. Install Zig (pinned version, e.g. 0.13.x — record in doc + CI matrix). `zig version`, `zig cc --version`.
2. Write the "no-commit" hello: Zig program calling your C++ `ascii_lower` via `@import("c.zig")`? Or Zig reimplementation compared byte-for-byte on 100 filenames? Do the COMPARISON (don't replace).
3. Decision table: per `10/11/14/37-time-helper` fn: keep C++ / mirror in Zig-test / port to Zig+`extern C`. Fill it; port NOTHING yet (ports start in 82).

## Stretch
- Read Zig stdlib `std.fs`, `std.json`, `std.hash` docs — map each to a repo use (walk? escape? FNV?).

## Verify
- [ ] Zig toolchain pinned + hello-compare runs; decision table written; zero repo files changed.
