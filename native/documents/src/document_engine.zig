// wayer_documents — recursive document filter.
// Ported from native/documents/src/document_engine.cpp

const std = @import("std");
const core = @import("../core/src/core.zig");

const TARGET_EXTENSIONS = &.{".pdf", ".epub", ".docx", ".txt", ".md"};

/// Filter documents by extension
pub fn filterDocuments(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const st = std.fs.cwd().stat(path) catch return errorToJson(allocator, "invalid_directory");
    if (st.kind != .dir) return errorToJson(allocator, "invalid_directory");

    var items_json = std.ArrayList(u8).init(allocator);
    defer items_json.deinit();
    var first = true;

    var iter = try std.fs.cwd().iterateDirRecursive(path, .{});
    defer iter.deinit();

    while (try iter.next()) |entry| {
        const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{entry.path, entry.name});
        defer allocator.free(full_path);

        const st2 = std.fs.cwd().stat(full_path) catch continue;
        if (st2.kind != .file) continue;

        const ext = std.fs.path.ext(full_path);
        const ext_lower = std.ascii.lower(ext) catch continue;
        defer allocator.free(ext_lower);

        var is_doc = false;
        for (TARGET_EXTENSIONS) |valid_ext| {
            if (std.mem.eql(u8, ext_lower, valid_ext)) {
                is_doc = true;
                break;
            }
        }

        if (is_doc) {
            if (!first) try items_json.appendSlice(",");
            first = false;

            const sz = st2.size;
            const name_escaped = core.json_util.jsonEscape(allocator, entry.name) catch continue;
            defer allocator.free(name_escaped);
            const path_escaped = core.json_util.jsonEscape(allocator, full_path) catch continue;
            defer allocator.free(path_escaped);
            try std.fmt.bufPrintZ(&items_json,
                "{\"name\":\"{s}\",\"path\":\"{s}\",\"size\":{}}",
                .{name_escaped, path_escaped, sz});
        }
    }

    const path_escaped = core.json_util.jsonEscape(allocator, path) catch return errorToJson(allocator, "escape_failed");
    defer allocator.free(path_escaped);
    const json = try std.fmt.allocPrint(allocator, "{\"path\":\"{s}\",\"documents\":[{s}]}", .{path_escaped, items_json.items});
    return json;
}

pub export fn wayer_filter_documents(payload: [*c]const u8) [*c]const u8 {
    const allocator = std.heap.page_allocator;
    const json = filterDocuments(allocator, std.mem.span(payload)) catch return errorToCStr(allocator, "filter_failed");
    return std.mem.toNullTerminated(allocator, json) catch "";
}

fn errorToJson(allocator: std.mem.Allocator, reason: []const u8) ![]u8 {
    return try std.fmt.allocPrint(allocator, "{{\"error\":\"{s}\"}}", .{reason});
}

fn errorToCStr(allocator: std.mem.Allocator, reason: []const u8) [*c]const u8 {
    const err = try std.fmt.allocPrint(allocator, "{{\"status\":\"error\",\"reason\":\"{s}\"}}", .{reason}) catch return "";
    return std.mem.toNullTerminated(allocator, err) catch "";
}