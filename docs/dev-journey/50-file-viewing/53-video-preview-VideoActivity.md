# 53 — Video preview: `VideoActivity` (thumbnail + stream, never full-load)

## Goal
Videos preview without copying/loading whole file.

## Touches
- `app/src/main/java/com/example/wayer/ui/VideoActivity.java`, `res/layout/activity_video.xml`
- `FileOpenHelper.java` (mime + intent fallback), `extension_map` video exts

## How it works today
VideoView/ExoPlayer? (Read file — note which.) Check: thumbnail before play, seek, rotation, cleanup on destroy.

## Guided tasks
1. Identify player (VideoView vs ExoPlayer/Media3). If VideoView: evaluate migrating to Media3 ExoPlayer (dep weight vs features). Don't migrate yet — write the tradeoff note.
2. Fixes: (a) thumbnail frame (`MediaMetadataRetriever` async), (b) mute-autoplay-muted? NO autoplay with sound — tap-to-play, (c) release player in `onPause/onDestroy` (leak hunt), (d) unsupported codec -> "Open with..." fallback.
3. Scrub perf: keyframe seek; show duration + size overlay.

## Stretch
- Trim/share clip? OUT for now — needs Media3 transformer + storage perms. Park with reason.

## Verify
- [ ] mp4/mkv/webm thumbnail + play + rotate without leak; bad codec degrades gracefully.
