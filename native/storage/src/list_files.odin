package storage

import "core:fmt"
import "core:strings"

import core_heart "../../core/src"


list_files :: proc(path: string) -> string {
	c_path := strings.clone_to_cstring(path, context.temp_allocator)
	d := wayer_fs_opendir(c_path)
	if d == nil {
		return `{"error":"invalid_directory"}`
	}
	defer wayer_fs_closedir(d)

	sb := strings.builder_make(context.temp_allocator)
	strings.write_string(&sb, `{"files":[`)
	first := true
	ent: WayerFsEntry
	for wayer_fs_readdir(d, &ent) != 0 {
		name := strings.string_from_ptr(cast([^]u8)ent.name, int(ent.name_len))
		if !first { strings.write_string(&sb, ",") }
		first = false
		fmt.sbprintf(&sb, `"%s"`, core_heart.json_escape(name))
	}
	strings.write_string(&sb, "]}")
	return strings.to_string(sb)
}