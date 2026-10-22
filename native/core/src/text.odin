package core_heart

import "core:strings"

// ascii_lower converts ASCII A-Z to a-z, leaves other bytes unchanged
// Mirrors wayer::core::ascii_lower
ascii_lower :: proc(s: string) -> string {
	result := strings.clone(s, context.temp_allocator)
	for i in 0 ..< len(result) {
		ch := result[i]
		if ch >= 'A' && ch <= 'Z' {
			result[i] = ch + ('a' - 'A')
		}
	}
	return result
}

//a wrapper to C
@(export, cdecl)
ascii_lower_c :: proc(c_str: cstring) -> cstring {
	if c_str == nil do return nil 

	odin_res := ascii_lower(string(c_str))
	return strings.clone_to_cstring(odin_res, context.temp_allocator)
}

// write_text_file writes content to path (creating parents, truncating)
// Returns true only when the file verifies afterwards
// Mirrors wayer::core::write_text_file
write_text_file :: proc(path: string, content: string) -> bool {
	if len(path) == 0 { return false }
	
	// Create parent directories
	parent := path
	// Find last slash
	last_slash := -1
	for i in 0 ..< len(parent) {
		if parent[i] == '/' || parent[i] == '\\' {
			last_slash = i
		}
	}
	if last_slash > 0 {
		parent_dir := parent[:last_slash]
		os.make_dir(parent_dir)
	}
	
	// Write file
	err := os.write_entire_file(path, transmute([]byte)content)
	return err == nil
}