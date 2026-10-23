package preview

import "core:fmt"
import "core:strings"

import core_heart "../../core/src"
import storage "../../storage/src"

kDefaultMaxBytes :: u64(64 * 1024)   // 64 KiB
kHardMaxBytes    :: u64(256 * 1024)  // 256 KiB hard cap

// read_text_file reads up to max_bytes of a text file
// Text:   {"path","size","truncated","line_count","lines":[...]}
// Binary: {"path","size","binary":true}
// Errors: {"error":"not_found" | "not_file" | "unreadable"}
// Mirrors wayer::preview::read_text_file
read_text_file :: proc(path: string, max_bytes: u64) -> string {
	if max_bytes == 0 { max_bytes = kDefaultMaxBytes }
	if max_bytes > kHardMaxBytes { max_bytes = kHardMaxBytes }
	
	size, _, is_file, ok := storage.fs.stat_c(path)
	if !ok { return `{"error":"not_found"}` }
	if !is_file { return `{"error":"not_file"}` }
	
	data, ok := storage.fs.read_file_c(path, usize(max_bytes))
	if !ok { return `{"error":"unreadable"}` }
	
	buf := data
	
	// Binary sniff: a NUL byte means "not text"
	for b in buf {
		if b == 0 {
			return fmt.tprintf(`{"path":"%s","size":%d,"binary":true}`,
				core_heart.json_escape(path), size)
		}
	}
	
	// Convert to string for line splitting
	text := string(buf)
	
	// Plain line split (\n terminated, tolerates \r\n)
	lines_json := ""
	line_count := 0
	start := 0
	
	for start <= len(text) {
		end := strings.index(text[start:], "\n")
		last := false
		if end == -1 {
			last = true
			end = len(text) - start
		}
		
		line := text[start : start+end]
		if len(line) > 0 && line[len(line)-1] == '\r' {
			line = line[:len(line)-1]
		}
		
		if line_count > 0 { lines_json += "," }
		lines_json += fmt.tprintf(`"%s"`, core_heart.json_escape(line))
		line_count++
		
		if last { break }
		start += end + 1
	}
	
	truncated := size > max_bytes
	return fmt.tprintf(
		`{"path":"%s","size":%d,"truncated":%s,"line_count":%d,"lines":[%s]}`,
		core_heart.json_escape(path), size,
		core_heart.bool_to_string(truncated), line_count, lines_json)
}