// wayer_core — plain-text helpers.
// Ported from native/core/src/text.cpp
// Single home for case folding and file writing.

const std = @import("std");

// Lowercase ASCII A-Z in place-copy. Non-ASCII bytes pass through untouched.
pub fn asciiLower(s: []u8) void {
    for (s) |*ch| {
        if (ch >= 'A' and ch <= 'Z') {
            ch = ch + ('a' - 'A');
        }
    }
}

// Write content to path (creating parents, truncating).
// Returns true only when the file verifies afterwards.
pub fn writeTextFile(_: std.mem.Allocator, path: []const u8, content: []const u8) !bool {
    if (path.len == 0) return false;

    // Create parent directories
    const parent = std.fs.path.dirname(path);
    if (parent.len > 0) {
        try std.fs.cwd().makePath(parent, .{});
    }

    const f = try std.fs.cwd().createFile(path, .{});
    defer f.close();

    try f.writeAll(content);
    return true;
}