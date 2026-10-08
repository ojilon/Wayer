# 50 — File reading: the preview contract (inline vs file-backed)

## Goal
Know when C++ returns content inline vs via file, and why.

## Touches
- `native/preview/src/preview.cpp:24`, `docs/BRIDGE_PLAN.md:254-260` (two-path table)
- `NativeEngine.readTextFileAsync:113`, `INDEX_META`, `SEARCH_INDEX` (file-backed)
- `ui/DocumentActivity.java`, `ui/InternalFragment.java` (private-home browser)

## How it works today
- Small capped reads (preview 64–256KB, meta) return INLINE JSON — files would be ceremony.
- Growable results (index, search, duplicates, large, stats, plan/report) go to FILES; JNI returns `{status,path}`.
- Preview refuses binaries (`binary:true` + metadata only).

## Guided tasks
1. List every native fn as inline vs file-backed. Any misclassified? (e.g. stats snapshot MUST be file — confirm it is.)
2. Add `preview` truncation UX if missing: `"showing first 64KB of 2.1MB"` + [Load more?] (second call with offset? spec it — don't implement yet).
3. Internals: confirm every out-file is browsable there. If a new module's files aren't, wire them in.

## Stretch
- Offset reads: `read_text_file(path, offset, max)` for big-log paging. Spec payload v2.

## Verify
- [ ] Classification table in code comment or PR; truncated file UX states size.
