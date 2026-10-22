// wayer_storage — stats document writer.
// Ported from native/storage/src/stats_json.cpp / stats_json.odin
// Hand-written JSON (no nlohmann/json dependency).

const std = @import("std");
const core = @import("../core/src/core.zig");

pub const FolderStat = struct {
    name: []u8,
    bytes: u64,
};

pub const StorageNumbers = struct {
    total_bytes: u64,
    used_bytes: u64,
    free_bytes: u64,
    progress_percent: u8,
    images: u64,
    videos: u64,
    audio: u64,
    documents: u64,
    foreign_files: u64,
    system: u64,
    others: u64,
    folders: []FolderStat,
};

pub fn buildStatsJson(allocator: std.mem.Allocator, n: StorageNumbers) ![]u8 {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    try buf.appendSlice("{\"total_bytes\":");
    try std.fmt.bufPrintZ(&buf, "{}", .{n.total_bytes});
    try buf.appendSlice(",\"used_bytes\":");
    try std.fmt.bufPrintZ(&buf, "{}", .{n.used_bytes});
    try buf.appendSlice(",\"free_bytes\":");
    try std.fmt.bufPrintZ(&buf, "{}", .{n.free_bytes});
    try buf.appendSlice(",\"progress_percent\":");
    try std.fmt.bufPrintZ(&buf, "{}", .{n.progress_percent});

    try buf.appendSlice(",\"breakdown\":{\"images\":");
    try std.fmt.bufPrintZ(&buf, "{}", .{n.images});
    try buf.appendSlice(",\"videos\":");
    try std.fmt.bufPrintZ(&buf, "{}", .{n.videos});
    try buf.appendSlice(",\"audio\":");
    try std.fmt.bufPrintZ(&buf, "{}", .{n.audio});
    try buf.appendSlice(",\"documents\":");
    try std.fmt.bufPrintZ(&buf, "{}", .{n.documents});
    try buf.appendSlice(",\"foreign\":");
    try std.fmt.bufPrintZ(&buf, "{}", .{n.foreign_files});
    try buf.appendSlice(",\"system\":");
    try std.fmt.bufPrintZ(&buf, "{}", .{n.system});
    try buf.appendSlice(",\"others\":");
    try std.fmt.bufPrintZ(&buf, "{}", .{n.others});

    try buf.appendSlice("},\"folders\":[");
    for (n.folders, 0..) |folder, i| {
        if (i > 0) try buf.appendSlice(",");
        try buf.appendSlice("{\"path\":\"");
        const escaped = try core.json_util.jsonEscape(allocator, folder.name);
        defer allocator.free(escaped);
        try buf.appendSlice(escaped);
        try buf.appendSlice("\",\"bytes\":");
        try std.fmt.bufPrintZ(&buf, "{}", .{folder.bytes});
        try buf.appendSlice("}");
    }
    try buf.appendSlice("]}");

    return buf.toOwnedSlice();
}