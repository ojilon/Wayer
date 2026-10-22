package storage

import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"

import core_heart "../../core/src"
import extension_map
import safety

// list_files returns JSON list of files in a directory (non-recursive)
// Mirrors wayer::storage::list_files
list_files :: proc(path: string) -> string {
	c_path := strings.clone_to_cstring(path, context.temp_allocator)
	
	// Use os.read_dir to list directory entries
	entries, err := os.read_dir(path)
	if err != nil {
		return `{"error":"invalid_directory"}`
	}
	
	sb := strings.builder_make(context.temp_allocator)
	strings.write_string(&sb, `{"files":[`)
	
	first := true
	for entry in entries {
		if !first {
			strings.write_string(&sb, ",")
		}
		first = false
		
		name := entry.name
		fmt.sbprintf(&sb, `"%s"`, core_heart.json_escape(name))
	}
	
	strings.write_string(&sb, "]}")
	return strings.to_string(sb)
}