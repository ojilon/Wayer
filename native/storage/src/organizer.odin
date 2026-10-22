package storage

import "core:fmt"
import "core:os"
import "core:strings"

import core_heart "../../core/src"
import extension_map
import safety

// Move represents one file move operation from the plan
Move :: struct {
	from: string,
	to: string,
}

// date_bucket returns YYYY-MM string for a file's mtime
// Mirrors wayer::storage::date_bucket
date_bucket :: proc(path: string) -> string {
	info, err := os.stat(path)
	if err != nil { return "unknown-date" }
	
	t := info.mod_time()
	// Odin's time.Time has year(), month() methods
	year := t.year()
	month := int(t.month())
	
	return fmt.tprintf("%04d-%02d", year, month)
}

// plan_organize generates a JSON plan of moves
// Mirrors wayer::storage::plan_organize
plan_organize :: proc(root_path: string) -> string {
	root := root_path
	json := `{"moves":[`
	first := true
	
	err := walk_files(root, proc(entry: os.DirEntry) {
		if !entry.is_file() { return }
		
		src := strings.concatenate({root, "/", entry.name}, context.temp_allocator)
		ext := strings.split(src, ".", context.temp_allocator)[-1]
		if len(ext) > 0 { ext = "." + ext }
		category := extension_map.category_for_extension(ext)
		
		// Only file types we actually recognize AND intend to relocate
		// Images stay where they are for now
		if category == "others" || category == "images" { return }
		
		bucket := date_bucket(src)
		dest := strings.concatenate({root, "/", category, "/", bucket, "/", entry.name}, context.temp_allocator)
		
		if dest == src { return }
		
		if !first { json += "," }
		first = false
		json += fmt.tprintf(`{"from":"%s","to":"%s"}`, 
			core_heart.json_escape(src),
			core_heart.json_escape(dest))
	})
	
	if err != nil {
		return `{"moves":[]}`
	}
	
	json += "]}"
	return json
}

// plan_organize_to_file writes plan to file
// Mirrors wayer::storage::plan_organize_to_file
plan_organize_to_file :: proc(root_path: string, out_path: string) -> string {
	json := plan_organize(root_path)
	if !core_heart.write_text_file(out_path, json) {
		return `{"status":"error","reason":"write_failed"}`
	}
	return fmt.tprintf(`{"status":"ok","path":"%s"}`, core_heart.json_escape(out_path))
}

// apply_organize_file executes a plan file and writes a report
// Mirrors wayer::storage::apply_organize_file
apply_organize_file :: proc(plan_path: string, report_path: string) -> string {
	// Read plan file
	plan_data, err := os.read_entire_file(plan_path)
	if err != nil {
		return `{"status":"error","reason":"bad_plan"}`
	}
	
	plan_json := string(plan_data)
	
	// Parse JSON (simplified - we expect {"moves":[{"from":"...","to":"..."}...]})
	// For simplicity, we'll use a basic parser
	moves: []Move
	
	// Find "moves" array
	moves_start := strings.index(plan_json, `"moves":[`)
	if moves_start == -1 {
		return `{"status":"error","reason":"bad_plan"}`
	}
	moves_start += len(`"moves":[`)
	
	// Find closing ]
	brace_count := 0
	in_string := false
	escape_next := false
	moves_end := -1
	
	for i := moves_start; i < len(plan_json); i++ {
		ch := plan_json[i]
		if escape_next {
			escape_next = false
			continue
		}
		if ch == '\\' {
			escape_next = true
			continue
		}
		if ch == '"' && !escape_next {
			in_string = !in_string
			continue
		}
		if !in_string {
			if ch == '{' { brace_count++ }
			else if ch == '}' {
				brace_count--
				if brace_count == 0 {
					moves_end = i + 1
					break
				}
			}
		}
	}
	
	if moves_end == -1 {
		return `{"status":"error","reason":"bad_plan"}`
	}
	
	moves_text := plan_json[moves_start:moves_end]
	
	// Parse individual moves - simplified approach
	// Look for {"from":"...","to":"..."} patterns
	remaining := moves_text
	for {
		from_start := strings.index(remaining, `"from":"`)
		if from_start == -1 { break }
		from_start += len(`"from":"`)
		from_end := strings.index(remaining[from_start:], `"`)
		if from_end == -1 { break }
		from := remaining[from_start : from_start + from_end]
		
		to_start := strings.index(remaining[from_start+from_end:], `"to":"`)
		if to_start == -1 { break }
		to_start += from_start + from_end + len(`"to":"`)
		to_end := strings.index(remaining[to_start:], `"`)
		if to_end == -1 { break }
		to := remaining[to_start : to_start + to_end]
		
		moves = append(moves, Move{from = from, to = to}, context.temp_allocator)
		
		// Move past this object
		next_brace := strings.index(remaining[to_start+to_end:], `}`)
		if next_brace == -1 { break }
		remaining = remaining[to_start+to_end+next_brace+1:]
	}
	
	moved := 0
	failed := 0
	skipped := 0
	errors: []string
	
	const kMaxErrors = 100
	
	note_error := proc(from: string, reason: string) {
		if len(errors) >= kMaxErrors { return }
		errors = append(errors, fmt.tprintf(`{"from":"%s","reason":"%s"}`, core_heart.json_escape(from), core_heart.json_escape(reason)), context.temp_allocator)
	}
	
	for move in moves {
		if len(move.from) == 0 || len(move.to) == 0 {
			skipped++
			continue
		}
		
		// Check source exists
		_, err := os.stat(move.from)
		if err != nil {
			skipped++
			continue
		}
		
		// Create destination directory
		to_path := move.to
		// Find parent directory
		last_slash := -1
		for i := 0; i < len(to_path); i++ {
			if to_path[i] == '/' || to_path[i] == '\\' {
				last_slash = i
			}
		}
		if last_slash > 0 {
			parent := to_path[:last_slash]
			err = os.make_dir(parent)
			if err != nil {
				failed++
				note_error(move.from, "mkdir_failed")
				continue
			}
		}
		
		// Handle existing destination
		dest := to_path
		_, err = os.stat(dest)
		if err == nil {
			// File exists, add _dup suffix
			dot := strings.last_index_byte(dest, '.')
			if dot > 0 {
				dest = dest[:dot] + "_dup" + dest[dot:]
			} else {
				dest += "_dup"
			}
		}
		
		// Move file
		err = os.rename(move.from, dest)
		if err != nil {
			failed++
			note_error(move.from, "move_failed")
		} else {
			moved++
		}
	}
	
	// Build report JSON
	sb := strings.builder_make(context.temp_allocator)
	fmt.sbprintf(&sb, `{"moved":%d,"failed":%d,"skipped":%d,"errors":[`, moved, failed, skipped)
	
	for i, e in errors {
		if i > 0 { strings.write_string(&sb, ",") }
		strings.write_string(&sb, e)
	}
	
	strings.write_string(&sb, "]}")
	report_json := strings.to_string(sb)
	
	if !core_heart.write_text_file(report_path, report_json) {
		return `{"status":"error","reason":"write_failed"}`
	}
	
	return fmt.tprintf(`{"status":"ok","path":"%s"}`, core_heart.json_escape(report_path))
}