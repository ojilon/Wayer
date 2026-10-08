# 102 — Thumbnails: stb (header-only) vs libjpeg-turbo vs MediaStore (pick lazy first)

## Goal
Fast grids (38/52) without native decode weight until proven needed.

## Touches
- Java: `ContentResolver.loadThumbnail` (first choice), `MediaMetadataRetriever` (video frames, 53)
- Native candidates: `stb_image.h` (public-domain, header-only, JPEG/PNG/WebP-ish) vs libjpeg-turbo (fast, heavier build) vs none
- `native/media/` (placeholder per MODULES — metadata extraction future)

## How it works today
No native decode. Thumbnails Java-side or absent (audit 38/52 gaps first).

## Guided tasks
1. Measure: Java `loadThumbnail` for 200-image grid (time, jank, cache hit?). If smooth — STOP, no native lib. Document measurement.
2. If slow/missing RAW: trial `stb_image.h` vendored (100 pattern: single header, INTERFACE lib `wayer_stb`, only `wayer_media` links). Decode bounds + subsample in native, return path to downscaled file? (File-backed again!) Prototype behind flag.
3. EXIF orientation: `ExifInterface` Java-side regardless (cheap). Don't decode for rotation.
4. Decision doc: when libjpeg-turbo would win (batch server-side? PC-side thumbs in 64.4 auto-sort receipt?). Likely never on phone — write it down so you stop revisiting.

## Stretch
- BlurHash placeholders (tiny string per image, pretty grids)? Evaluate lib weight vs `loadThumbnail` cache. Probably skip — note why.

## Verify
- [ ] Measurement recorded; cheapest path shipped; native decode only if measured need.
