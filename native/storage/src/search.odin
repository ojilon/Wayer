package storage

import "core:fmt"
import "core:os"
import "core:strings"

import core_heart "../../core/src"
import safety

// SearchResult mirrors the C++ SearchResult struct
SearchResult :: struct {
	name: string,
	path: string,
	is_dir: bool,
	match_score: int, // 100 exact, 50 related
}

// search_files performs case-insensitive file-name search
// Mirrors wayer::storage::search_files
search_files :: proc(root_path: string, query: string) -> string {
	q_lower := core_heart.ascii_lower(query)
	if len(q_lower) == 0 {
		return `{"exact_matches":[],"related_matches":[]}`
	}
	
	exacts: []SearchResult
	relateds: []SearchResult
	
	// Walk the directory tree
	err := walk_files(root_path, proc(entry: os.DirEntry) {
		name := entry.name
		name_lower := core_heart.ascii_lower(name)
		is_dir := entry.is_dir()
		
		full_path := strings.concatenate({root_path, "/", name}, context.temp_allocator)
		
		if name_lower == q_lower {
			exacts = append(exacts, SearchResult{
				name = name,
				path = full_path,
				is_dir = is_dir,
				match_score = 100,
			}, context.temp_allocator)
		} else if strings.contains(name_lower, q_lower) {
			relateds = append(relateds, SearchResult{
				name = name,
				path = full_path,
				is_dir = is_dir,
				match_score = 50,
			}, context.temp_allocator)
		}
	})
	
	if err != nil {
		return `{"exact_matches":[],"related_matches":[]}`
	}
	
	// Build JSON
	sb := strings.builder_make(context.temp_allocator)
	strings.write_string(&sb, `{"exact_matches":[`)
	
	for i, result in exacts {
		if i > 0 { strings.write_string(&sb, ",") }
		fmt.sbprintf(&sb, `{"name":"%s","path":"%s","is_dir":%s}`,
			core_heart.json_escape(result.name),
			core_heart.json_escape(result.path),
			core_heart.bool_to_string(result.is_dir))
	}
	
	strings.write_string(&sb, `],"related_matches":[`)
	
	for i, result in relateds {
		if i > 0 { strings.write_string(&sb, ",") }
		fmt.sbprintf(&sb, `{"name":"%s","path":"%s","is_dir":%s}`,
			core_heart.json_escape(result.name),
			core_heart.json_escape(result.path),
			core_heart.bool_to_string(result.is_dir))
	}
	
	strings.write_string(&sb, "]}")
	return strings.to_string(sb)
}

// search_files_to_file writes search results to a file
// Mirrors wayer::storage::search_files_to_file
search_files_to_file :: proc(root_path: string, query: string, out_path: string) -> string {
	json := search_files(root_path, query)
	if !core_heart.write_text_file(out_path, json) {
		return `{"status":"error","reason":"write_failed"}`
	}
	return fmt.tprintf(`{"status":"ok","path":"%s"}`, core_heart.json_escape(out_path))
}

// walk_files walks a directory tree and calls visit for each entry
// Skips excluded directories
walk_files :: proc(root: string, visit: proc(entry: os.DirEntry)) -> error {
	// Use os.walk_dir for recursive traversal
	iter := os.walk_dir(root)
	for {
		entry, err := iter.next()
		if err == os.ErrIteratorDone { break }
		if err != nil { return err }
		
		// Check if excluded
		if entry.is_dir() {
			parent := root // simplified; in reality we'd track the parent
			if safety.is_excluded_dir(entry.name, parent) {
				continue // skip this directory
			}
		}
		
		// Skip symlinks
		if entry.is_symlink() { continue }
		
		// Only visit regular files
		if entry.is_file() {
			visit(entry)
		}
	}
	return nil
}