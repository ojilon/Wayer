package documents

import "core:fmt"
import "core:os"
import "core:strings"

import core_heart "../../core/src"

foreign import libc  "system:c"

@(default_calling_convention = "c")
foreign libc {
	wayer_is_directory :: proc(path: cstring) -> c.int ---
	walk_and_filter :: proc(root: cstring, buf: [^]u8, buf_max: c.int, buf_len: ^int, first: ^b32) -> i32 ---
}

// TARGET_EXTENSIONS mirrors the C++ TARGET_EXTENSIONS
TARGET_EXTENSIONS :: [5]string {
	".pdf", ".epub", ".docx", ".txt", ".md",
}

// filter_documents recursively finds documents with target extensions
// Mirrors wayer::documents::filter_documents
filter_documents :: proc(path: string) -> string {
	// Check if directory exists
	if wayer_is_directory(cstring(path)) == 0 {
		return `{"error": "invalid_directory"}`
	}
	
	context.allocator = allocator 
	path_cstring := strings.clone_to_cstring(path, context.temp_allocator)

	//pre-allocate a static array buffer to hand over to C 
	BUFFER_SZIE :: 1024 * 64 //64KB for documents array elements
	c_buffer := make([]u8, BUFFER_SZIE, context.temp_allocator)

	buf_len := 0
	first_item: b32 = true 
	
	//call the C function 
	err_code := walk_and_filter(path_cstring, ([^]u8)(raw_data(c_buffer)), BUFFER_SZIE, &buf_len, &first_item)
	if err_code != 0 {
		return `{"error": "invalid_directory"}`
	}

	//extract the c result
	documents_array_content := string(c_buffer[:buf_len])

	//generate final json usinf structural builder format
	b := strings.builder_make(context.allocator)

	// Construct the wrapper string safely
    fmt.sbprintf(&b, `{{\"path\":\"%s\",\"documents\":[%s]}}`, path, documents_array_content)
	
	//return fmt.tprintf(`{"path":"%s","documents":[%s]}`, core_heart.json_escape(path), items_json)
	return strings.to_string(b)
}

// walk_files walks a directory tree and calls visit for each entry
walk_files :: proc(root: string, visit: proc(entry: os.DirEntry)) -> error {
	iter := os.walk_dir(root)
	for {
		entry, err := iter.next()
		if err == os.ErrIteratorDone { break }
		if err != nil { return err }
		visit(entry)
	}
	return nil
}