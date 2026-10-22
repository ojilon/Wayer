// wayer_core — JSON output helpers.
// Ported from native/core/src/json_util.cpp
// Escapes a string for embedding inside "..." in hand-written JSON.

const std = @import("std");

pub fn jsonEscape(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    // Reserve approximate capacity to avoid reallocations
    try buf.reserve(s.len + 8);

    for (s) |ch| {
        // Treat as unsigned byte for correct handling of > 127
        const c = ch;
        switch (c) {
            '"' => try buf.appendSlice("\\\""),
            '\\' => try buf.appendSlice("\\\\"),
            '\n' => try buf.appendSlice("\\n"),
            '\r' => try buf.appendSlice("\\r"),
            '\t' => try buf.appendSlice("\\t"),
            else => if (c < 0x20) {
                try buf.appendSlice("\\u");
                try std.fmt.bufPrintZ(&buf, "{0>04x}", .{c});
            } else {
                try buf.append(c);
            },
        }
    }
    return buf.toOwnedSlice();
}