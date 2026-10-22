// wayer_storage — extension → category map.
// Ported from native/storage/src/extension_map.cpp / extension_map.odin

const std = @import("std");

pub const Category = enum(u8) {
    Images,
    Videos,
    Audio,
    Documents,
    Foreign_Files,
    Others,
};

/// ".JPG" -> ".jpg" without allocating (called once per file, so it must be cheap)
pub fn categoryForName(name: []const u8) Category {
    const dot = std.mem.lastIndexByte(name, '.') orelse return Category.Others;
    if (dot == 0) return Category.Others; // hidden file like ".nomedia"

    const ext = name[dot..];
    if (ext.len > 16) return Category.Others;

    var buf: [16]u8 = undefined;
    for (ext, 0..) |ch, i| {
        buf[i] = if (ch >= 'A' and ch <= 'Z') ch + ('a' - 'A') else ch;
    }
    const lower = buf[0..ext.len];

    // Compare without string switch (Zig doesn't allow switch on strings)
    if (std.mem.eql(u8, lower, ".jpg") or std.mem.eql(u8, lower, ".jpeg") or
        std.mem.eql(u8, lower, ".png") or std.mem.eql(u8, lower, ".webp") or
        std.mem.eql(u8, lower, ".gif") or std.mem.eql(u8, lower, ".heic")) {
        return Category.Images;
    }
    if (std.mem.eql(u8, lower, ".mp4") or std.mem.eql(u8, lower, ".mkv") or
        std.mem.eql(u8, lower, ".avi") or std.mem.eql(u8, lower, ".webm") or
        std.mem.eql(u8, lower, ".3gp")) {
        return Category.Videos;
    }
    if (std.mem.eql(u8, lower, ".mp3") or std.mem.eql(u8, lower, ".wav") or
        std.mem.eql(u8, lower, ".flac") or std.mem.eql(u8, lower, ".m4a") or
        std.mem.eql(u8, lower, ".ogg")) {
        return Category.Audio;
    }
    if (std.mem.eql(u8, lower, ".pdf") or std.mem.eql(u8, lower, ".txt") or
        std.mem.eql(u8, lower, ".doc") or std.mem.eql(u8, lower, ".docx") or
        std.mem.eql(u8, lower, ".xls") or std.mem.eql(u8, lower, ".xlsx")) {
        return Category.Documents;
    }
    if (std.mem.eql(u8, lower, ".apk") or std.mem.eql(u8, lower, ".obb")) {
        return Category.Foreign_Files;
    }
    return Category.Others;
}