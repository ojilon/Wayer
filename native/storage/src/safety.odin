package storage

import "core:strings"

is_excluded_dir :: proc(name: string, parent: string) -> bool {
	// Android private data — never scan (scoped storage denies most anyway).
	if name == "data" || name == "obb" {
		if strings.has_suffix(parent, "/Android") { return true }
	}
	switch name {
	case ".thumbnails", "thumbnails", ".trashed", ".trash", ".cache",
	     "LOST.DIR", ".dwayer_cache", "wayer_trash", ".wayer_trash":
		return true
	}
	return false
}