package documents

import "core:fmt"
import "core:os"
import "core:strings"

import core_heart "../../core/src"

foreign import libc  "system:c"

@(default_calling_convention = "c")
foreign libc {
	wayer_is_directory :: proc(path: cstring) -> c.int ---
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
	
	items_json := ""
	first := true
	
	// Walk recursively
	err = walk_files(path, proc(entry: os.DirEntry) {
		if !entry.is_file() { return }
		
		full_path := strings.concatenate({path, "/", entry.name}, context.temp_allocator)
		ext := strings.split(full_path, ".", context.temp_allocator)[-1]
		if len(ext) > 0 { ext = "." + ext }
		ext_lower := core_heart.ascii_lower(ext)
		
		is_doc := false
		for valid_ext in TARGET_EXTENSIONS {
			if ext_lower == valid_ext {
				is_doc = true
				break
			}
		}
		
		if is_doc {
			if !first { items_json += "," }
			first = false
			
			size := u64(0)
			info, err := os.stat(full_path)
			if err == nil {
				size = u64(info.size())
			}
			
			items_json += fmt.tprintf(`{"name":"%s","path":"%s","size":%d}`,
				core_heart.json_escape(entry.name),
				core_heart.json_escape(full_path),
				size)
		}
	})
	
	if err != nil {
		return `{"error": "invalid_directory"}`
	}
	
	return fmt.tprintf(`{"path":"%s","documents":[%s]}`, core_heart.json_escape(path), items_json)
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