# 17 — `wayer_preview`: capped read-only text preview

## Goal
Understand the safe file-read pattern (caps, binary sniff, truncation flag).

## Touches
- `native/preview/include/wayer/preview/preview.hpp`
- `native/preview/src/preview.cpp:24-75`
- Java: `NativeEngine.readTextFileAsync:113` (`ACTION_READ_TEXT_FILE=19`), `ui/DocumentActivity.java`

## How it works today
- `read_text_file(path, max_bytes)`: default 64KB, hard cap 256KB. `exists`/`is_regular_file`/`file_size` checks with `error_code`.
- Reads `want=min(size,max)`, NUL byte -> `{"binary":true}` metadata only (no garbled UI).
- Splits on `\n`, tolerates `\r\n`, escapes each line, returns `{path,size,truncated,line_count,lines[]}`.
- Small capped reads return INLINE (not via file) — files are for growable results only.

## Guided tasks
1. Trace DocumentActivity open -> `readTextFileAsync` -> preview -> lines render. Note `truncated=true` UX (does it say "showing first 64KB"? If not, add it — Java-side).
2. Edge: empty file, 0-byte `max_bytes` (means default!), >hard-max request, permission-denied. List expected JSON for each.
3. Improvement: add `max_lines` param? Or keep byte-cap only? Decide + implement the smaller one.
4. Binary sniff upgrade: also detect common binaries by magic (PDF `%PDF`, PNG, ZIP `PK`)? Return `binary:true + kind:"pdf"` hint for icon choice.

## Stretch
- Syntax tinting: return `language:"md|txt|java|..."` from extension for Java-side highlighting (no native highlight — just the hint).

## Verify
- [ ] Open .txt/.md/.log on device; binary file shows metadata, never garbage.
