# Wayer — Storage Subsystem: Open Flags & Decisions

Running log of unresolved gaps, deliberate simplifications, and decisions
that were made for now but may need revisiting. Update this file whenever
a new corner is cut or a flag gets resolved.

---

## RESOLVED

### Device capacity hardcoding (64GB constant)
`analyse_storage_space.cpp` originally hardcoded `RETAIL_64GB` to pad
`statvfs`'s partition-visible total up to a "real" device capacity.
Replaced with a `known_device_bytes` parameter — Java should query the
real capacity via `StorageManager`/`StatFs` (native `statvfs` can't see
past the app-visible partition) and pass it in, rather than C++ guessing.
**Status**: signature updated, Java-side query not yet wired up.

---

## OPEN

### JSON parsing gap (native has no JSON parser)
Every native function so far only *produces* JSON via `std::format` —
none of them *parse* JSON. This was fine while all data flowed
Java → native (simple strings) and native → Java (JSON out). It breaks
down for `apply_organize`, which needs Java to send back a *plan*
(a list of from/to move pairs) for native to execute.

**Current workaround**: `apply_organize` accepts a pipe-delimited string
(`from1|to1|from2|to2|...`) instead of JSON, reusing the existing
`split_payload()` helper already used for `ACTION_FIND_LARGE_FILES` and
`ACTION_SEARCH_FILES`. No parser needed.

**Revisit when**: a Java → native payload needs real nesting (not just
flat pairs) — e.g. if duplicate-group resolution needs to send back
"delete these 3 of these 5 paths, per group" in one call. At that point,
pull in a header-only JSON library (nlohmann/json is the standard pick)
rather than extending the pipe-delimited format further.

### Images excluded from `plan_organize`
`plan_organize` currently skips `category == "images"` entirely —
images are left wherever they are. Reason: camera-roll/DCIM conventions
mean other apps (gallery, camera, backup tools) expect photos in
predictable locations, and blindly relocating them by date could break
those assumptions in ways documents/audio/video don't have.

**Needs its own design pass later**: likely a separate, opt-in flow
rather than folding into the generic organizer.

### `apply_organize` collision handling untested against real data
Apply appends `_dup` to the filename stem when a destination already
exists, rather than overwriting. This logic hasn't been run against a
real directory tree yet — only reasoned through. Test with `plan_organize`
output eyeballed first before ever calling `apply_organize` on real
`/storage/emulated/0` data.

### `Android/data` pruning — untested at scale
`dir_walker.hpp`'s `walk_files` uses `disable_recursion_pending()` to
prune `Android/data`, `Android/obb`, `.thumbnails`, `.trashed`, and the
app's own cache dir before descending into them. This is the *design*
for avoiding permission-denied churn and irrelevant scanning, but hasn't
been profiled on a real device with a large `Android/data` tree yet.

### Storage cache invalidation is time-only
`storage_cache.cpp`'s `read_cache_if_fresh` only checks file age
(`max_age_seconds`), not whether the underlying filesystem actually
changed. A user deleting a large file and immediately checking the
Storage screen could see stale numbers for up to `STATS_MAX_AGE_SECONDS`
(currently 300s / 5 min in `StorageFragment.java`). Acceptable for now;
if this becomes annoying, consider invalidating the cache explicitly
after any native mutation (`FileMutator.delete`, `apply_organize`)
rather than only on a timer.

### Duplicate finder: no external JSON library, nested arrays by hand
`find_duplicates` builds nested JSON arrays (`groups of groups of paths`)
manually with `std::format` + string concatenation. Works, but is the
kind of shape that gets fragile if the structure grows another level
(e.g. adding per-file metadata inside each group). Same "revisit with
nlohmann/json" flag as above.

---

## Native ↔ Java communication conventions (for reference)

- **Java → native, simple values**: raw string payload (see
  `ACTION_GET_STORAGE_STATS`, root path only).
- **Java → native, multiple values**: pipe-delimited
  (`root|min_bytes|max_results` for `ACTION_FIND_LARGE_FILES`;
  `cache_path|root|max_age_seconds` for `ACTION_GET_CACHED_STATS`;
  `from|to|from|to|...` for `ACTION_APPLY_ORGANIZE`). Parsed on the
  native side with `split_payload()` in `wayer_engine.cpp`.
- **Native → Java**: always JSON, built by hand with `std::format` +
  `json::escape()` (see `json_util.hpp`). Parsed on the Java side with
  `org.json.JSONObject`/`JSONArray`.
- **Async bridge**: `NativeEngine.processActionAsync(actionId, payload, callback)`
  — callback receives the raw JSON/response string, always dispatched
  back to the fragment on the UI thread before touching `binding`.