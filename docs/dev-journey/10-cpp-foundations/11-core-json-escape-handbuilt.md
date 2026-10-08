# 11 — `core::json::escape` + hand-built JSON (why not always nlohmann)

## Goal
Know when hand-rolled JSON is fine vs when `nlohmann/json` is required.

## Touches
- `native/core/include/wayer/core/json_util.hpp`, `native/core/src/json_util.cpp`
- Flat builders: `storage/modules/cleaner/src/large_files.cpp:53-67`, `duplicate_finder.cpp:94-105`
- Nested: `storage/modules/organizer/src/file_organizer.cpp:9,165-169` (uses `nlohmann/json`)

## How it works today
- `core::json::escape` escapes quotes/backslashes/controls for embedding in `"..."`.
- Flat payloads (`{name,path,size}` lists) use `ostringstream` + `std::format` — zero deps, fast.
- Nested/dynamic (organize `moves[]`, stats per-folder) use `nlohmann/json` (`third_party/json/include/nlohmann/json.hpp`).
- Rule from `BRIDGE_PLAN Step 0/5`: don't rewrite working flat builders for fashion.

## Guided tasks
1. Read `json_util.cpp` fully. List which chars it escapes. What about `\n`, `\t`, unicode?
2. Find one escape bug risk: what if filename contains `"`? Trace `large_files.cpp:60-64` — confirm it escapes both name and path.
3. Improvement: add `json::quote(string_view) -> string` helper returning `"..."` already quoted, to avoid missing quotes. Use it in ONE module.
4. Decide per module: which current `std::format`-JSON should migrate to nlohmann? (Hint: anything with nested arrays of arrays — duplicates.)

## Stretch
- Write a host test (plain `g++`) feeding evil filenames (`a"b\c`, newline) through escape.

## Verify
- [ ] No behavior change; `assembleDebug` green; evil-name search still lists correctly.
