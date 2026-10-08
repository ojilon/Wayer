# 34 — Large files: top-N over a size floor (harden + extend)

## Goal
Own the second shipped utility; fix edge bugs; add presets.

## Touches
- `native/storage/modules/cleaner/src/large_files.cpp:26-78`
- Java: `NativeEngine.findLargeFilesAsync:85`, `CleanerFragment` Large-files tab
- Shared: `walker.cpp` vs direct `recursive_directory_iterator` (note: large_files does NOT use walk_files — why? exclusion? fix or document)

## How it works today
Walk, filter `sz>=min_bytes` (default 10MB), `partial_sort` top-N (default 50), emit `{min_bytes,count,files[{name,path,size}]}`. `*_to_file` writes out + `{status,path}`.

## Guided tasks
1. Bug: `want==0` (empty result) -> `partial_sort(begin,begin+0,end)`? Verify safe; add `if(found.empty())` early-return `{count:0,files:[]}`.
2. Unify walk: switch to `walk_files()` so `safety.hpp` exclusions apply, OR document why direct iterator is intentional. Pick + justify.
3. Presets (Java-side, same engine): "Old large videos" (video ext + age filter), "Old downloads" (Download/ + 90d). Add `min_bytes/max_results` presets + ONE new native param (`older_than_days`)? Spec payload v2 first.
4. Cancel: add `atomic<bool>` cancel (see walker stretch) — button "Stop scan". Implement plumbing for this module first.

## Stretch
- Age filter: need `last_write_time` (see organizer `date_bucket`). Reuse helper — don't duplicate time code; propose `core/time.hpp`.

## Verify
- [ ] Empty tree returns valid JSON; exclusions honored; preset finds known 200MB video.
