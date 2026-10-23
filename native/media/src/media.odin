// =============================================================================
// media.odin — media module stub (future: metadata, thumbnails)
//
// Part of package media (wayer_media). Currently a placeholder — media
// metadata extraction and thumbnail path generation will land here when the
// app needs native media handling. Today playback uses Android's
// ExoPlayer/MediaPlayer on the Java side; this module just anchors the
// CMake target so the dependency graph is complete.
//
// Dependency graph (see native/MODULES.md)
//   media depends on core + storage (for file type + paths)
//   Nothing depends on media yet (intentionally leaf)
//
// When to implement
//   * Metadata probe (duration, bitrate, codec) via MediaMetadataRetriever
//     bridge or ffmpeg wrapper under third_party/
//   * Thumbnail paths under app cache (e.g. <cache>/thumbs/<hash>.jpg)
//   * Keep the same file-backed pattern: Java passes paths, native writes files
//
// Mirrors: wayer::media::media_module_anchor in media_placeholder.cpp
// =============================================================================

package media

// media_module_anchor is the anchor symbol for the CMake target.
// Returns 0 so the lib is non-empty and linkable even while stubbed.
media_module_anchor :: proc() -> int {
	return 0
}
