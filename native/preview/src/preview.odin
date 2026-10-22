package preview

import "core:fmt"
import "core:os"
import "core:strings"

import core_heart "../../core/src"

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
	
	info, err := os.stat(path)
	if err != nil { return `{"error":"not_found"}` }
	if !info.is_file() { return `{"error":"not_file"}` }
	
	size := u64(info.size())
	
	file, err := os.open(path)
	if err != nil { return `{"error":"unreadable"}` }
	defer file.close()
	
	want := usize(max_bytes)
	if size < max_bytes { want = usize(size) }
	
	buf := make([]u8, want, context.temp_allocator)
	n, err := file.read(buf)
	if err != nil || n < 0 { return `{"error":"unreadable"}` }
	buf = buf[:n]
	
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