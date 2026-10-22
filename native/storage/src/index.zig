// wayer_storage — file-backed index: build / meta / search.
// Ported from native/storage/src/index.cpp / index_c.c / index.odin
// Heavy-lifting (directory walk, JSON streaming) stays in index_c.c via C ABI.

const std = @import("std");
const core = @import("../core/src/core.zig");

const kDefaultMaxResults: u64 = 50;
const kHardMaxResults: u64 = 200;

/// Get index file path from app paths
fn indexFilePath(allocator: std.mem.Allocator) ![]u8 {
    if (!core.paths.appPathsInitialized()) return "";
    const cache = core.paths.appPaths().cache;
    return try std.fmt.allocPrint(allocator, "{s}/index/files.json", .{cache});
}

/// Build index from root directory
pub export fn wayer_build_index(root: [*c]const u8, _: [*c]const u8) [*c]const u8 {
    const allocator = std.heap.page_allocator;
    const path = indexFilePath(allocator) catch return errorToCStr(allocator, "paths_not_initialized");
    if (path.len == 0) return errorToCStr(allocator, "paths_not_initialized");
    defer allocator.free(path);

    const c_path = try std.cstr.fromSlice(allocator, path);
    defer allocator.free(c_path);

    std.fs.cwd().makePath(std.fs.path.dirname(path), .{}) catch return errorToCStr(allocator, "mkdir_failed");

    const out = try std.fs.cwd().createFile(path, .{});
    defer out.close();

    var count: usize = 0;
    try out.writeAll("{\"root\":\"" ) catch return errorToCStr(allocator, "write_failed");
    try out.writeAll(core.json_util.jsonEscape(allocator, std.mem.span(root))) catch return errorToCStr(allocator, "escape_failed");
    try out.writeAll("\",\"files\":[") catch return errorToCStr(allocator, "write_failed");

    var first = true;
    var iter = try std.fs.cwd().iterateDirRecursive(std.mem.span(root), .{});
    defer iter.deinit();

    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;

        const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{entry.path, entry.name});
        defer allocator.free(full_path);

        if (!first) try out.writeAll(",") catch return errorToCStr(allocator, "write_failed");
        first = false;

        try out.writeAll("\"") catch return errorToCStr(allocator, "write_failed");
        try out.writeAll(core.json_util.jsonEscape(allocator, full_path)) catch return errorToCStr(allocator, "escape_failed");
        try out.writeAll("\"") catch return errorToCStr(allocator, "write_failed");
        count += 1;
    }

    try out.writeAll("]}") catch return errorToCStr(allocator, "write_failed");

    return successToCStr(allocator, path, count);
}

/// Get index metadata
pub export fn wayer_index_meta(index_path: [*c]const u8) [*c]const u8 {
    const allocator = std.heap.page_allocator;
    const st = std.fs.cwd().stat(std.mem.span(index_path)) catch return errorToCStr(allocator, "missing");

    const modified = st.mtime;
    return try std.fmt.allocPrint(allocator, "{{\"status\":\"ready\",\"path\":\"{s}\",\"bytes\":{},\"modified_unix\":{}}}",
        .{std.mem.span(index_path), st.size, modified}) catch errorToCStr(allocator, "fmt_failed");
}

/// Search index and write results to file
pub export fn wayer_search_index_to_file(query: [*c]const u8, max_results: u64, _: [*c]const u8, _: [*c]const u8) [*c]const u8 {
    const allocator = std.heap.page_allocator;
    var mr = max_results;
    if (mr == 0) mr = kDefaultMaxResults;
    if (mr > kHardMaxResults) mr = kHardMaxResults;

    _ = query;

    return errorToCStr(allocator, "not_implemented");
}

/// Group index entries by day
pub export fn wayer_group_index_by_day(_: [*c]const u8, _: [*c]const u8, _: c_int, _: c_int) [*c]const u8 {
    // Simplified implementation - delegate to C for now
    // Full Zig implementation would be complex
    return errorToCStr(std.heap.page_allocator, "not_implemented");
}

fn errorToCStr(allocator: std.mem.Allocator, reason: []const u8) [*c]const u8 {
    const err = try std.fmt.allocPrint(allocator, "{{\"status\":\"error\",\"reason\":\"{s}\"}}", .{reason}) catch return "";
    return std.mem.toNullTerminated(allocator, err) catch "";
}

fn successToCStr(allocator: std.mem.Allocator, path: []const u8, count: usize) [*c]const u8 {
    const msg = try std.fmt.allocPrint(allocator, "{{\"path\":\"{s}\",\"count\":{}}}", .{path, count}) catch return "";
    return std.mem.toNullTerminated(allocator, msg) catch "";
}

fn searchIndexSimple(_: std.mem.Allocator, _: std.fs.File, _: []u8, _: u64, _: [*c]const u8) [*c]const u8 {
    // Simplified implementation
    return errorToCStr(std.heap.page_allocator, "not_implemented");
}