// =============================================================================
// extension_map.odin — file extension → category mapping
//
// Part of package storage. Maps lowercased file extensions to the six
// categories used in Storage stats and Home breakdown. The lists are taken
// directly from native/storage/src/extension_map.cpp so Odin and C++ agree.
//
// Categories
//   Images        — .jpg .jpeg .png .webp .gif .heic
//   Videos        — .mp4 .mkv .avi .webm .3gp
//   Audio         — .mp3 .wav .flac .m4a .ogg
//   Documents     — .pdf .txt .doc .docx .xls .xlsx
//   Foreign_Files — .apk .obb  (sideloadable / opaque)
//   Others        — everything else (including no extension / hidden files)
//
// Implementation notes
//   * Input name may have any case; we lowercase the extension stack-locally.
//   * Extension buffer is capped at 16 bytes — longer extensions fall to Others.
//   * `.Others` is the default for hidden files like `.nomedia` (dot at pos 0).
//   * Mirrors category_for_name() semantics from extension_map.cpp exactly.
//
// Mirrors: wayer::storage::category_for_name, category_for_extension
// =============================================================================

package storage

import "core:strings"

// Category is the six-way split shown in Storage stats.
// NOTE: `foreign` would clash with Odin keyword; we use Foreign_Files.
Category :: enum {
	Images,
	Videos,
	Audio,
	Documents,
	Foreign_Files,
	Others,
}

// category_for_name maps a file *name* (with dot) to a Category.
// The extension is lowercased inline without allocation past a stack buffer.
category_for_name :: proc(name: string) -> Category {
	dot := strings.last_index_byte(name, '.')
	// No dot, or dot is first char (hidden file like ".nomedia")
	if dot <= 0 {
		return .Others
	}

	ext := name[dot:] // includes leading dot, e.g. ".JPG"

	// Stack buffer — no heap allocation, cheap per-file.
	buf: [16]u8
	if len(ext) > len(buf) {
		return .Others
	}

	for i in 0 ..< len(ext) {
		ch := ext[i]
		if ch >= 'A' && ch <= 'Z' {
			ch += 'a' - 'A'
		}
		buf[i] = ch
	}
	lower := string(buf[:len(ext)])

	switch lower {
	case ".jpg", ".jpeg", ".png", ".webp", ".gif", ".heic":
		return .Images
	case ".mp4", ".mkv", ".avi", ".webm", ".3gp":
		return .Videos
	case ".mp3", ".wav", ".flac", ".m4a", ".ogg":
		return .Audio
	case ".pdf", ".txt", ".doc", ".docx", ".xls", ".xlsx":
		return .Documents
	case ".apk", ".obb":
		return .Foreign_Files
	}
	return .Others
}

// category_for_extension maps a lowercased extension (with dot) to Category.
// Caller must already have lowercased; we just switch.
category_for_extension :: proc(ext: string) -> Category {
	switch ext {
	case ".jpg", ".jpeg", ".png", ".webp", ".gif", ".heic":
		return .Images
	case ".mp4", ".mkv", ".avi", ".webm", ".3gp":
		return .Videos
	case ".mp3", ".wav", ".flac", ".m4a", ".ogg":
		return .Audio
	case ".pdf", ".txt", ".doc", ".docx", ".xls", ".xlsx":
		return .Documents
	case ".apk", ".obb":
		return .Foreign_Files
	}
	return .Others
}
