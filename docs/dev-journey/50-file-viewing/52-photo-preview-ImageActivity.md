# 52 — Photo preview: `ImageActivity` (fast,OOM-safe, zoomable)

## Goal
Photos feel instant without decoding full 100MP in memory.

## Touches
- `app/src/main/java/com/example/wayer/ui/ImageActivity.java`, `res/layout/activity_image.xml`
- Java: MediaStore thumbnails vs `BitmapFactory.Options.inSampleSize`, `FileOpenHelper.java`
- Native: NOT involved (no decode in C++ today — see `100-libs` for stb/libjpeg decision)

## How it works today
Full image load (check: subsampled? placeholder? zoom?). Risk: OOM on large panoramas.

## Guided tasks
1. Audit: `inSampleSize` calculation? `inJustDecodeBounds` first? Background decode? Pinch-zoom (PhotoView lib vs hand `ScaleGestureDetector`)? List gaps.
2. Fix order: (a) bounds-first + sample to screen size, (b) placeholder + error drawable, (c) EXIF rotation respect, (d) swipe between folder images (pass file list + index via intent, preload neighbors).
3. HEIC/RAW: detect unsupported -> friendly "can't preview, details + share" screen (never crash).
4. Share/Open-with Intent from preview (FileProvider — check `AndroidManifest.xml` provider paths).

## Stretch
- Basic info overlay: dimensions, size, date (from `ExifInterface`, no native needed).

## Verify
- [ ] 50MP photo opens <1s, no OOM, rotation correct, swipe works.
