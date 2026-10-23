// =============================================================================
// safety.odin — directory exclusion rules for storage walks
//
// Part of package storage. Decides which subdirectories to *skip entirely*
// during a recursive walk — we prune them at the top of the subtree instead
// of filtering their contents, so we never descend into them.
//
// Excluded names (mirror android_fs.c / safety.cpp):
//   .thumbnails, thumbnails, .trashed, .trash, .cache, LOST.DIR,
//   .dwayer_cache, wayer_trash, .wayer_trash
//   Android/data and Android/obb (scoped storage — unreadable anyway)
//
// The check is intentionally conservative: a false positive just hides a
// rarely-needed folder; a false negative walks into system trash and bloats
// the index with thousands of tiny thumbnail files.
//
// Mirrors: wayer::storage::is_excluded_dir
//          is_excluded_name in native/storage/src/index_c.c
// =============================================================================

package storage

import "core:strings"

// is_excluded_dir reports whether directory `name` under `parent` should be skipped.
// `parent` is the full path of the containing directory (e.g. "/sdcard/Android").
// `name` is the bare entry name (e.g. "data").
is_excluded_dir :: proc(name: string, parent: string) -> bool {
	// Android private data — never scan (scoped storage denies most anyway).
	if name == "data" || name == "obb" {
		if strings.has_suffix(parent, "/Android") {
			return true
		}
	}

	switch name {
	case ".thumbnails", "thumbnails", ".trashed", ".trash", ".cache",
	     "LOST.DIR", ".dwayer_cache", "wayer_trash", ".wayer_trash":
		return true
	}
	return false
}
