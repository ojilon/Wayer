// =============================================================================
// json_util.odin — minimal JSON escaping for hand-written payloads
//
// Part of package core_heart (wayer_core). This module provides the only
// JSON manipulation we do without a third-party lib: escaping a string for
// embedding inside "..." . Larger documents (stats, index) use nlohmann/json
// on the C++ side; Odin only needs to safely embed paths.
//
// Design rules
//   * No dependencies beyond core:strings / core:fmt.
//   * Uses context.temp_allocator — callers in wayer_core.odin wrap the
//     whole route in `defer free_all(context.temp_allocator)` so no leak.
//   * ASCII-centric: file names are mostly ASCII; control bytes get \uXXXX.
//
// Mirrors: wayer::core::json::escape in native/core/src/json_util.cpp
// =============================================================================

package json_util

import "core:strings"
import "core:fmt"

// json_escape returns `s` with JSON special characters escaped.
// The result lives on context.temp_allocator and is valid until the caller
// frees the temp allocator (wayer_core.odin does this per JNI call).
json_escape :: proc(s: string) -> string {
	sb := strings.builder_make(context.temp_allocator)
	for r in s {
		switch r {
		case '"':
			strings.write_string(&sb, "\\\"")
		case '\\':
			strings.write_string(&sb, "\\\\")
		case '\n':
			strings.write_string(&sb, "\\n")
		case '\r':
			strings.write_string(&sb, "\\r")
		case '\t':
			strings.write_string(&sb, "\\t")
		case:
			if r < 0x20 {
				// Control character → \uXXXX (e.g. NUL, BEL)
				fmt.sbprintf(&sb, "\\u%04x", u32(r))
			} else {
				strings.write_rune(&sb, r)
			}
		}
	}
	return strings.to_string(sb)
}

// bool_to_string converts a bool to the JSON literals "true"/"false".
// Mirrors the C++ helper `bool_json(bool)` in paths.cpp.
bool_to_string :: proc(b: bool) -> string {
	if b {
		return "true"
	}
	return "false"
}
