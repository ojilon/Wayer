// =============================================================================
// logging.odin — thin logging facade for native code
//
// Part of package core_heart. On Android it forwards to
// __android_log_print so logcat tags work (adb logcat -s Wayer*). On host
// builds (unit tests, desktop) it falls back to stderr.
//
// Android bionic note
//   __android_log_print lives in liblog, linked automatically by the NDK.
//   We call it via C FFI (system:c) instead of using core:os file logs,
//   because file-based logging in Odin would need core:os which on Android
//   10 would use statx-seccomp-blocked paths. The C++ side optionally logs
//   to <app_root>/logs/; Odin keeps logging to logcat only (file logs are
//   best-effort and not required for correctness).
//
// Mirrors: wayer::core::log::info / error in native/core/src/logging.cpp
// =============================================================================

package core_heart

import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"

// ---------------------------------------------------------------------------
// C FFI — Android log bridge
// ---------------------------------------------------------------------------

foreign import libc "system:c"

@(default_calling_convention = "c")
foreign libc {
	// Android NDK: <android/log.h>. Priority values match android/log.h.
	__android_log_print :: proc(prio: c.int, tag: cstring, fmt: cstring, msg: cstring) -> c.int ---
}

// LogLevel mirrors the C++ priority mapping.
LogLevel :: enum {
	Info,
	Error,
}

// log writes a message with the given level.
// On Android → __android_log_print; elsewhere → stderr.
log :: proc(level: LogLevel, tag: string, msg: string) {
	ctag := strings.clone_to_cstring(tag, context.temp_allocator)
	cmsg := strings.clone_to_cstring(msg, context.temp_allocator)

	when ODIN_PLATFORM_SUBTARGET == .Android {
		// Android log priorities (from <android/log.h>)
		ANDROID_LOG_INFO  :: c.int(4)
		ANDROID_LOG_ERROR :: c.int(6)

		prio: c.int
		switch level {
		case .Info:
			prio = ANDROID_LOG_INFO
		case .Error:
			prio = ANDROID_LOG_ERROR
		}

		//make the string a literal c string
		__android_log_print(prio, ctag, "%s", cmsg)
	} else {
		// Host fallback — use os.stderr which is ^os.File in Odin Oct 2025.
		// fmt.fprintln handles ^os.File as io.Writer via os.stream_from_handle.
		prefix: string
		switch level {
		case .Info:
			prefix = "[I]"
		case .Error:
			prefix = "[E]"
		}
		// Use stderr explicitly; WASI/host builds have it.
		fmt.fprintf(os.stream_from_handle(os.stderr), "%s[%s] %s\n", prefix, tag, msg)
	}
}

// info logs an informational message.
// Mirrors wayer::core::log::info
info :: proc(tag: string, msg: string) {
	log(.Info, tag, msg)
}

// error logs an error message.
// Mirrors wayer::core::log::error
error :: proc(tag: string, msg: string) {
	log(.Error, tag, msg)
}

// infof is a C-compat helper for call sites that pass C strings.
// Mirrors wayer::core::log::infof
infof :: proc(tag: cstring, msg: cstring) {
	info(string(tag), string(msg))
}

// errorf is a C-compat helper for call sites that pass C strings.
// Mirrors wayer::core::log::errorf
errorf :: proc(tag: cstring, msg: cstring) {
	error(string(tag), string(msg))
}
