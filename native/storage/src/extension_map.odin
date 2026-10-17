package storage

import "core:strings"

// ───────────── Categories (ports extension_map.cpp) ─────────────
// Replace the lists with the real ones from extension_map.cpp.

Category :: enum {
	Images,
	Videos,
	Audio,
	Documents,
	Foreign_Files,
	Others,
}

// ".JPG" -> ".jpg" without allocating (called once per file, so it must be cheap)
category_for_name :: proc(name: string) -> Category {
	dot := strings.last_index_byte(name, '.') //seperate the extension, without the "."
	if dot <= 0 { return .Others } // no extension, or a hidden file like ".nomedia"

	ext := name[dot:] //slice the extension
	buf: [16]u8
	if len(ext) > len(buf) { return .Others }

	//iterate through and change any "capital" character in the extension to_lower
	for i in 0 ..< len(ext) {
		ch := ext[i]
		if ch >= 'A' && ch <= 'Z' { ch += 'a' - 'A' }
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