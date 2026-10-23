// =============================================================================
// text.odin — plain-text helpers shared by every native module
//
// Part of package core_heart. Provides ASCII case folding (used for
// case-insensitive file name search) and a bionic-safe text file writer.
//
// Android 10 / bionic abstraction
//   File writes go through wayer_fs_write_file (android_fs.c) not core:os,
//   because core:os on API 29 may use statx which is seccomp-blocked.
//   create_directories is done via wayer_fs_mkdir_p (mkdir only).
//
// Mirrors: wayer::core::ascii_lower, write_text_file in native/core/src/text.cpp
// =============================================================================

package core_heart

import "base:runtime"
import "core:c"
import "core:strings"

foreign import android_fs "system:c"

@(default_calling_convention = "c")
foreign android_fs {
	wayer_fs_mkdir_p    :: proc(path: cstring) -> c.int ---
	wayer_fs_write_file :: proc(path: cstring, data: rawptr, n: c.size_t) -> c.int ---
}

// ---------------------------------------------------------------------------
// ASCII helpers
// ---------------------------------------------------------------------------

// ascii_lower lowercases ASCII A-Z in a copy; non-ASCII bytes pass through.
// Mirrors wayer::core::ascii_lower. File-name matching only needs ASCII.
ascii_lower :: proc(s: string) -> string {
	result := strings.clone(s, context.temp_allocator)

	//transmute to mutable byte slice
	bytes := transmute([]u8)result
	for i in 0 ..< len(bytes) {
		ch := bytes[i]
		if ch >= 'A' && ch <= 'Z' {
			bytes[i] = ch + ('a' - 'A')
		}
	}

	//transmute back to immutable string
	return transmute(string)bytes
}

// ascii_lower_c is the C-callable version for JNI/shim tests.
// Exported as "ascii_lower_c" for wayer_shim.cpp compat (if still linked).
@(export, link_name = "ascii_lower_c")
ascii_lower_c :: proc "c" (c_str: cstring) -> cstring {
	context = runtime.default_context()
	if c_str == nil {
		return nil
	}
	odin_res := ascii_lower(string(c_str))
	return strings.clone_to_cstring(odin_res, context.temp_allocator)
}

// ---------------------------------------------------------------------------
// File writer
// ---------------------------------------------------------------------------

// write_text_file writes `content` to `path` (creating parents, truncating).
// Returns true only when the C wrapper reports success.
// Mirrors wayer::core::write_text_file
write_text_file :: proc(path: string, content: string) -> bool {
	if len(path) == 0 {
		return false
	}

	// Ensure parent directory exists via C mkdir -p (bionic-safe)
	last_slash := -1
	for i in 0 ..< len(path) {
		if path[i] == '/' || path[i] == '\\' {
			last_slash = i
		}
	}
	if last_slash > 0 {
		parent_dir := path[:last_slash]
		c_parent := strings.clone_to_cstring(parent_dir, context.temp_allocator)
		wayer_fs_mkdir_p(c_parent)
	}

	// Write via C wrapper (open/write/close only — no statx)
	c_path := strings.clone_to_cstring(path, context.temp_allocator)
	ret := wayer_fs_write_file(c_path, raw_data(content), len(content))
	return ret == 0
}
