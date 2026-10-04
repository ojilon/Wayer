# media — migration & improvements

**CMake target:** `wayer_media`  
**Status:** placeholder only — no legacy sources yet.

## When to add code

- Video/audio metadata extraction
- Thumbnail generation paths under `app_paths().cache`
- Not required for basic file listing

## Rules

- Depend on `wayer_core` (+ `wayer_storage` if scanning files)
- Prefer system players on Java for playback
- Third-party codecs go in `native/third_party/` with clear licenses
