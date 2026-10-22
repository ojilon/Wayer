// wayer_storage_search — case-insensitive file-name search.
// Ported from native/storage/modules/search/src/file_search.cpp

const std = @import("std");
const core = @import("../../core/src/core.zig");
const walker = @import("../walker.zig");

pub const SearchResult = struct {
    name: []u8,
    path: []u8,
    is_dir: bool,
    match_score: i32, // 100 exact, 50 related
};

/// Search files by name (case-insensitive)
pub fn searchFiles(allocator: std.mem.Allocator, root_path: []const u8, query: []const u8) ![]u8 {
    var exacts = std.ArrayList(SearchResult).init(allocator);
    var relateds = std.ArrayList(SearchResult).init(allocator);
    defer {
        exacts.deinit();
        relateds.deinit();
    }

    const q_lower = std.ascii.lower(query) catch return errorToJson(allocator, "lowercase_failed");
    defer allocator.free(q_lower);

    if (q_lower.len == 0) {
        return try std.fmt.allocPrint(allocator, "{\"exact_matches\":[],\"related_matches\":[]}");
    }

    // Walk files using the storage walker
    var scan = walker.Scan.init(allocator);
    defer scan.deinit();

    const root_trimmed = std.mem.trimRight(u8, root_path, "/");
    walker.scanDir(allocator, &scan, root_trimmed, root_trimmed) catch {};

    // Note: The walker doesn't give us individual file paths easily for search
    // We'll need a dedicated search walk or use recursive iteration
    // For now, use std.fs for search (matches original C++ behavior)
    var iter = try std.fs.cwd().iterateDirRecursive(root_trimmed, .{});
    defer iter.deinit();

    while (try iter.next()) |entry| {
        const raw_name = entry.name;
        const name_lower = std.ascii.lower(raw_name) catch continue;
        defer allocator.free(name_lower);

        const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{entry.path, raw_name});
        defer allocator.free(full_path);

        const st = std.fs.cwd().stat(full_path) catch continue;
        const is_dir = st.kind == .dir;

        if (std.mem.eql(u8, name_lower, q_lower)) {
            exacts.append(SearchResult{
                .name = try allocator.dupe(u8, raw_name),
                .path = full_path,
                .is_dir = is_dir,
                .match_score = 100,
            }) catch {};
        } else if (std.mem.indexOf(u8, name_lower, q_lower) != null) {
            relateds.append(SearchResult{
                .name = try allocator.dupe(u8, raw_name),
                .path = full_path,
                .is_dir = is_dir,
                .match_score = 50,
            }) catch {};
        }
    }

    // Build JSON
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    try buf.appendSlice("{\"exact_matches\":[");
    for (exacts.items, 0..) |result, i| {
        if (i > 0) try buf.appendSlice(",");
        const name_escaped = core.json_util.jsonEscape(allocator, result.name) catch continue;
        defer allocator.free(name_escaped);
        const path_escaped = core.json_util.jsonEscape(allocator, result.path) catch continue;
        defer allocator.free(path_escaped);
        try std.fmt.bufPrintZ(&buf,
            "{\"name\":\"{s}\",\"path\":\"{s}\",\"is_dir\":{s}}",
            .{name_escaped, path_escaped, if (result.is_dir) "true" else "false"});
    }
    try buf.appendSlice("],\"related_matches\":[");
    for (relateds.items, 0..) |result, i| {
        if (i > 0) try buf.appendSlice(",");
        const name_escaped = core.json_util.jsonEscape(allocator, result.name) catch continue;
        defer allocator.free(name_escaped);
        const path_escaped = core.json_util.jsonEscape(allocator, result.path) catch continue;
        defer allocator.free(path_escaped);
        try std.fmt.bufPrintZ(&buf,
            "{\"name\":\"{s}\",\"path\":\"{s}\",\"is_dir\":{s}}",
            .{name_escaped, path_escaped, if (result.is_dir) "true" else "false"});
    }
    try buf.appendSlice("]}");

    return buf.toOwnedSlice();
}

/// Search files and write results to file
pub export fn wayer_search_files_to_file(root: [*c]const u8, query: [*c]const u8, out_path: [*c]const u8) [*c]const u8 {
    const allocator = std.heap.page_allocator;
    const json = searchFiles(allocator, std.mem.span(root), std.mem.span(query)) catch return errorToCStr(allocator, "search_failed");
    defer allocator.free(json);

    core.text.writeTextFile(allocator, std.mem.span(out_path), json) catch return errorToCStr(allocator, "write_failed");

    const escaped = core.json_util.jsonEscape(allocator, std.mem.span(out_path)) catch return errorToCStr(allocator, "escape_failed");
    defer allocator.free(escaped);
    const msg = try std.fmt.allocPrint(allocator, "{\"status\":\"ok\",\"path\":\"{s}\"}", .{escaped}) catch return errorToCStr(allocator, "fmt_failed");
    return std.mem.toNullTerminated(allocator, msg) catch "";
}

fn errorToJson(allocator: std.mem.Allocator, reason: []const u8) ![]u8 {
    return try std.fmt.allocPrint(allocator, "{{\"error\":\"{s}\"}}", .{reason});
}

fn errorToCStr(allocator: std.mem.Allocator, reason: []const u8) [*c]const u8 {
    const err = try std.fmt.allocPrint(allocator, "{{\"status\":\"error\",\"reason\":\"{s}\"}}", .{reason}) catch return "";
    return std.mem.toNullTerminated(allocator, err) catch "";
}