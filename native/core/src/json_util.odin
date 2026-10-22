package core_heart

import "core:strings"
import "core:fmt"

json_escape :: proc(s: string) -> string {
	sb := strings.builder_make(context.temp_allocator)
	for r in s {
		switch r {
		case '"':  strings.write_string(&sb, `\"`)
		case '\\': strings.write_string(&sb, `\\`)
		case '\n': strings.write_string(&sb, `\n`)
		case '\r': strings.write_string(&sb, `\r`)
		case '\t': strings.write_string(&sb, `\t`)
		case:
			if r < 0x20 {
				fmt.sbprintf(&sb, "\\u%04x", u32(r))
			} else {
				strings.write_rune(&sb, r)
			}
		}
	}
	return strings.to_string(sb)
}

bool_to_string :: proc(b: bool) -> string {
	if b { return "true" }
	return "false"
}