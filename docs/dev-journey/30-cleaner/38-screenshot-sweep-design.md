# 38 — Screenshot sweep (month-grouped, thumbnails are Java-side)

## Goal
Design the first media-aware utility without native image work.

## Touches
- Native: scoped walk of `DCIM/Screenshots` (+ `Pictures/Screenshots` vendor paths) with age filter (reuse 37)
- Java: MediaStore thumbnails, `ImageActivity.java`, Cleaner new tab
- `extension_map.cpp` (images), `FileAdapter.iconFor` (image icons)

## How it works today
Not built. CLEANER_IDEAS Medium: grouped by month with thumbnails.

## Guided tasks
1. Enumerate screenshot dirs across OEMs (DCIM/Screenshots, Pictures/Screenshots, ...). Walk tries each, missing = empty, not error.
2. Group by month: reuse `date_bucket` (`YYYY-MM`) from organizer (after 37 extraction). Result `{months:[{month,count,bytes,files[]}]}`.
3. Thumbnails: Java `ContentResolver.loadThumbnail` async, cached, placeholder while loading. NEVER in adapter bind on UI thread. Sketch loader owned by tab, cancelled on tab switch.
4. Delete UX: per-month "Review" -> grid -> multi-select -> trash (39). No month-bulk-delete without opening grid.

## Stretch
- Perceptual dup photos? Explicitly OUT (see CLEANER_IDEAS Later). Note why false positives need their own design.

## Verify
- [ ] Design doc + dir list + JSON sketch reviewed; no native image decode added.
