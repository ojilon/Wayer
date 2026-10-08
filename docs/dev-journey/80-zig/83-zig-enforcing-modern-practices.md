# 83 — Zig enforcing modern practices (what the language "carries")

## Goal
Use Zig's strictness to teach habits that feed BACK into your C++/Java.

## Touches
- All `native/**` style rules (`MODULES.md:79-89`), `Bridge` busy/lease rules (26), preview-then-apply (24/39)

## Practices Zig forces (map each to a repo rule)
1. **No hidden allocation** (explicit `Allocator` param) -> C++: pass `string& out` / `string_view in`, avoid temp `std::string` in hot walks (11/15). Java: reuse `StringBuilder` in adapters, no `+` in `onBind`.
2. **`error` return traces** (`try/catch err`) -> C++: every `error_code` CHECKED (walker `ec.clear` discipline, 15); add `[[nodiscard]]` to fns returning bool/status. Java: `Result` (21) checked at every call site — grep for ignored `Result`.
3. **Comptime tables** (`comptime` map) -> `EXTENSION_MAP` (14) + icon map (54/75) generated from ONE `categories.json` (81.4) with compile-time size check. No drift.
4. **No null without `?`** (`?T` + `orelse`) -> JNI payload parse: every `find("|")` missing -> explicit error, never `substr(npos)` (see 18 drill). Java: `TextUtils.isEmpty` guards (25).
5. **Tests beside code** (`test` blocks in same file) -> keep `*.cpp` + host `*_test.cpp` + `*.zig` test blocks; run ALL in `wayer_zig_checks` + `testDebugUnitTest`.

## Guided tasks
1. Pick ONE practice (2 recommended): audit all `error_code` ignores in `native/` (`grep -n "ec;"`), fix by handling or logging. Small PR, big safety.
2. Add `[[nodiscard]]` to `write_text_file`, `category_for_extension`, `find_*_to_file` decls. Fix callers that drop the bool.
3. Java mirror: audit ignored `Result` returns (`FileMutator.*` callers not checking `.ok`). Fix ONE screen to show the message (toast/snackbar), not swallow.

## Stretch
- `zig fmt` + `clang-format` parity: same line width/brace style? Document in `native/MODULES.md` style section.

## Verify
- [ ] Audit PR merged; no ignored errors in touched module; Java shows failure messages.
