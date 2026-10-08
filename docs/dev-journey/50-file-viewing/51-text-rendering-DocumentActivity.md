# 51 — Text rendering: `DocumentActivity` (txt/md/log today, pdf later)

## Goal
Make text viewing trustworthy before attempting PDF/Office.

## Touches
- `app/src/main/java/com/example/wayer/ui/DocumentActivity.java`
- `res/layout/activity_document.xml`, `NativeEngine.readTextFileAsync`, `preview/preview.cpp`
- Later: `native/documents/` (`document_engine.cpp`), `100-libs` (pdf)

## How it works today
Capped lines JSON -> TextView/ScrollView. No syntax tint, no line numbers, no search-in-file.

## Guided tasks
1. Read `DocumentActivity` fully. Note: intent extra key (path?), loader (async?), rotation handling, `truncated` display.
2. Improvements in order: (a) monospace toggle for logs/code, (b) line numbers (perf: only <5k lines), (c) Markdown-lite render (headings/bold/code via `Markwon`? or hand-span? — evaluate lib weight first), (d) search-in-file (highlight matches, prev/next).
3. Large-file guard: >256KB -> "Preview capped" + [Open truncated] [Cancel]. Never OOM on 50MB log.
4. Encoding: UTF-8 assume? What on failure (mojibake)? Detect + show "binary?" fallback linking to 50.

## Stretch
- Edit mode? Explicitly OUT until trash+history exist. Note why (accidental overwrite).

## Verify
- [ ] .txt/.md/.log/.json render; binary shows metadata; rotation keeps scroll.
