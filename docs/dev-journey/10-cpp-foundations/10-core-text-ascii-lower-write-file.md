# 10 — `wayer_core`: `ascii_lower` + `write_text_file` (start here)

## Goal
Understand the two functions every module reuses. Your first C++ edit.

## Touches
- `native/core/include/wayer/core/text.hpp:10-14`
- `native/core/src/text.cpp:12-32`
- Users: `native/storage/src/extension_map.cpp:22`, `storage/modules/cleaner/src/large_files.cpp:62`

## How it works today
- `ascii_lower(string s)` — takes by value (copy), folds A-Z only, non-ASCII passes
  through. Exactly what filename matching needs; no locale surprises.
- `write_text_file(path, content)` — creates parents (`create_directories`), opens
  `binary|trunc`, writes, returns `bool(out)`. The file-backed bridge depends on it:
  every `*_to_file` ends here. Returns false on empty path / bad stream.
- Style rules (`native/MODULES.md:79-89`): plain functions, `std::error_code` never
  exceptions, `static_cast` for narrowing, no `using namespace`.

## Guided tasks
1. Read `text.hpp` (16 lines) then `text.cpp` (34 lines) fully. Note pass-by-value vs const-ref.
2. Add a host-side mental test: `ascii_lower("Photo.JPG")` -> `"photo.jpg"`. Trace into `extension_map.cpp`.
3. Improvement 1 (safe): add `ascii_lower_inplace(std::string&)` overload? Or keep one? Decide + document why.
4. Improvement 2 (real): `write_text_file` should fsync? For now add a `write_text_file_atomic` idea: write to `.tmp` + rename. Don't implement yet — write the design in comments.

## Stretch
- Benchmark: is copying the string for lowercasing wasteful for 1M filenames? Propose `string_view` + compare without alloc.

## Verify
- [ ] `./gradlew :app:assembleDebug` still green (you touched header? rebuild).
- [ ] You can explain why non-ASCII passes through untouched.
