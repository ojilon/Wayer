package core_heart

import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"

// Log levels
LogLevel :: enum {
	Info,
	Error,
}

// log_to_android uses __android_log_print via C FFI
// On non-Android, falls back to stderr
foreign import libc "system:c"

@(default_calling_convention = "c")
foreign libc {
	// Android logging
	__android_log_print :: proc(prio: c.int, tag: cstring, fmt: cstring, msg: cstring) -> c.int ---
}

// log writes a message with the given level
log :: proc(level: LogLevel, tag: string, msg: string) {
	ctag := strings.clone_to_cstring(tag, context.temp_allocator)
	cmsg := strings.clone_to_cstring(msg, context.temp_allocator)
	
	when ODIN_OS == "android" {
		// Android log priorities
		ANDROID_LOG_INFO  :: c.int(4)
		ANDROID_LOG_ERROR :: c.int(6)
		
		prio: c.int
		switch level {
		case .Info:
			prio = ANDROID_LOG_INFO
		case .Error:
			prio = ANDROID_LOG_ERROR
		}
		__android_log_print(prio, ctag, "%s", cmsg)
	} else {
		// Fallback to stderr (matches C++ behavior)
		prefix: string
		switch level {
		case .Info:
			prefix = "[I]"
		case .Error:
			prefix = "[E]"
		}
		fmt.fprintf(os.stderr, "%s[%s] %s\n", prefix, tag, msg)
	}
}

// info logs an info message
// Mirrors wayer::core::log::info
info :: proc(tag: string, msg: string) {
	log(.Info, tag, msg)
}

// error logs an error message
// Mirrors wayer::core::log::error
error :: proc(tag: string, msg: string) {
	log(.Error, tag, msg)
}

// infof is a printf-style helper (for compatibility)
// Mirrors wayer::core::log::infof
infof :: proc(tag: cstring, msg: cstring) {
	info(string(tag), string(msg))
}

// errorf is a printf-style helper (for compatibility)
// Mirrors wayer::core::log::errorf
errorf :: proc(tag: cstring, msg: cstring) {
	error(string(tag), string(msg))
}