// =============================================================================
// list_files.odin — single-directory listing (Files tab)
//
// Part of package storage. Lists the contents of one directory (non-recursive)
// for the FilesFragment file browser. Uses the bionic-safe fs_android wrappers
// instead of core:os.read_dir, which on Android 10 might attempt statx.
//
// Output shape (what Java parses with JSONObject):
//   {"files":["photo.jpg","notes.txt", ...]}
//
// Error shape (when path is not a directory or unreadable):
//   {"error":"invalid_directory"}
//
// Why a separate file from walker.odin?
//   walker.odin recurses for stats; this file is deliberately non-recursive
//   and returns just names (not full paths) to keep the Files list lightweight.
//   The Transfer and Cleaner modules use the file-backed index for searches
//   over the whole tree — this is only for browsing one folder at a time.
//
// Mirrors: wayer::storage::list_files in native/storage/src/list_files.cpp
// =============================================================================

package storage

import "core:fmt"
import "core:strings"

import core_heart "../../core/src"
import fs "../../file_system_bridge/src"
import js_util "../../json_utils/src"

// list_files returns JSON with file names in `path` (non-recursive).
// Uses the bionic-safe WayerFsDir API (opendir/readdir/stat, no statx).
list_files :: proc(path: string) -> string {
	c_path := strings.clone_to_cstring(path, context.temp_allocator)
	d := fs.wayer_fs_opendir(c_path)
	if d == nil {
		return `{"error":"invalid_directory"}`
	}
	defer fs.wayer_fs_closedir(d)

	sb := strings.builder_make(context.temp_allocator)
	strings.write_string(&sb, `{"files":[`)

	first := true
	ent: fs.WayerFsEntry
	for fs.wayer_fs_readdir(d, &ent) != 0 {
		//turn the cstring + length to odin string with zero allocation
		name := string(([^]u8)(ent.name)[:ent.name_len])
		if !first {
			strings.write_string(&sb, ",")
		}
		first = false
		fmt.sbprintf(&sb, `"%s"`, js_util.json_escape(name))
	}
	strings.write_string(&sb, "]}")
	return strings.to_string(sb)
}
