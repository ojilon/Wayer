// wayer_storage_cleaner — top-N largest files under a root.
// Ported from native/storage/modules/cleaner/src/large_files.cpp

const std = @import("std");
const core = @import("../../core/src/core.zig");

pub const LargeEntry = struct {
    name: []u8,
    path: []u8,
    size: u64,
};

/// Find large files
pub fn findLargeFiles(allocator: std.mem.Allocator, root_path: []const u8, min_bytes: u64, max_results: i32) ![]u8 {
    var found = std.ArrayList(LargeEntry).init(allocator);
    defer found.deinit();

    var mr = max_results;
    if (mr <= 0) mr = 50;
    if (min_bytes == 0) min_bytes = 10 * 1024 * 1024; // 10 MB default

    var iter = try std.fs.cwd().iterateDirRecursive(root_path, .{});
    defer iter.deinit();

    while (try iter.next()) |entry| {
        const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{entry.path, entry.name});
        defer allocator.free(full_path);

        const st = std.fs.cwd().stat(full_path) catch continue;
        if (st.kind != .file) continue;

        const sz = st.size;
        if (sz < min_bytes) continue;

        found.append(LargeEntry{
            .name = try allocator.dupe(u8, entry.name),
            .path = full_path,
            .size = sz,
        }) catch {};
    }

    const want = @min(found.items.len, @as(usize, mr));
    std.sort.sort(LargeEntry, found.items, {}, struct {
        fn lessThan(a: LargeEntry, b: LargeEntry) bool {
            return a.size > b.size;
        }
    });
    _ = found.resizeRetainCapacity(want);

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    try buf.appendSlice("{\"min_bytes\":");
    try std.fmt.bufPrintZ(&buf, "{}", .{min_bytes});
    try buf.appendSlice(",\"count\":");
    try std.fmt.bufPrintZ(&buf, "{}", .{found.items.len});
    try buf.appendSlice(",\"files\":[");

    for (found.items, 0..) |entry, i| {
        if (i > 0) try buf.appendSlice(",");
        const name_escaped = core.json_util.jsonEscape(allocator, entry.name) catch continue;
        defer allocator.free(name_escaped);
        const path_escaped = core.json_util.jsonEscape(allocator, entry.path) catch continue;
        defer allocator.free(path_escaped);
        try std.fmt.bufPrintZ(&buf,
            "{\"name\":\"{s}\",\"path\":\"{s}\",\"size\":{}}",
            .{name_escaped, path_escaped, entry.size});
    }
    try buf.appendSlice("]}");

    return buf.toOwnedSlice();
}

/// Find large files and write to file
pub export fn wayer_find_large_files_to_file(root: [*c]const u8, min_bytes: u64, max_results: c_int, out_path: [*c]const u8) [*c]const u8 {
    const allocator = std.heap.page_allocator;
    const json = findLargeFiles(allocator, std.mem.span(root), min_bytes, max_results) catch return errorToCStr(allocator, "search_failed");
    defer allocator.free(json);

    core.text.writeTextFile(allocator, std.mem.span(out_path), json) catch return errorToCStr(allocator, "write_failed");

    const escaped = core.json_util.jsonEscape(allocator, std.mem.span(out_path)) catch return errorToCStr(allocator, "escape_failed");
    defer allocator.free(escaped);
    const msg = try std.fmt.allocPrint(allocator, "{\"status\":\"ok\",\"path\":\"{s}\"}", .{escaped}) catch return errorToCStr(allocator, "fmt_failed");
    return std.mem.toNullTerminated(allocator, msg) catch "";
}

fn errorToCStr(allocator: std.mem.Allocator, reason: []const u8) [*c]const u8 {
    const err = try std.fmt.allocPrint(allocator, "{{\"status\":\"error\",\"reason\":\"{s}\"}}", .{reason}) catch return "";
    return std.mem.toNullTerminated(allocator, err) catch "";
}