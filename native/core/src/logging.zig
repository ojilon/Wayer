// wayer_core — thin logging facade.
// Ported from native/core/src/logging.cpp
// Android: forwards to __android_log_print
// Host builds: falls back to stderr.

const std = @import("std");

const is_android = std.Target.current.os.tag == .android;

pub fn info(tag: []const u8, msg: []const u8) void {
    if (is_android) {
        // Use Android log via C
        _ = androidLogPrint(ANDROID_LOG_INFO, tag, msg);
    } else {
        std.log.info("[I][{s}] {s}", .{tag, msg});
    }
}

pub fn logError(tag: []const u8, msg: []const u8) void {
    if (is_android) {
        _ = androidLogPrint(ANDROID_LOG_ERROR, tag, msg);
    } else {
        std.log.err("[E][{s}] {s}", .{tag, msg});
    }
}

// printf-style helpers for call sites that already have formatted strings
pub fn infof(tag: ?[]const u8, msg: ?[]const u8) void {
    info(tag.? orelse "Wayer", msg.? orelse "");
}

pub fn errorf(tag: ?[]const u8, msg: ?[]const u8) void {
    logError(tag.? orelse "Wayer", msg.? orelse "");
}

// Android log constants and function
const ANDROID_LOG_INFO = 4;
const ANDROID_LOG_ERROR = 6;

extern "c" fn __android_log_print(prio: c_int, tag: [*c]const u8, fmt: [*c]const u8, ...) c_int;

fn androidLogPrint(prio: c_int, tag: []const u8, msg: []const u8) c_int {
    const c_tag = std.cstr.fromSlice(std.heap.page_allocator, tag) catch return -1;
    defer std.heap.page_allocator.free(c_tag);
    const c_msg = std.cstr.fromSlice(std.heap.page_allocator, msg) catch return -1;
    defer std.heap.page_allocator.free(c_msg);
    const c_fmt = std.cstr.fromSlice(std.heap.page_allocator, "%s") catch return -1;
    defer std.heap.page_allocator.free(c_fmt);
    return __android_log_print(prio, c_tag, c_fmt, c_msg);
}