// wayer_preview — read-only text preview.
// Ported from native/preview/src/preview.cpp

const std = @import("std");
const core = @import("../core/src/core.zig");

const kDefaultMaxBytes: usize = 64 * 1024;
const kHardMaxBytes: usize = 256 * 1024;

pub fn readTextFile(allocator: std.mem.Allocator, path: []const u8, max_bytes: usize) ![]u8 {
    var mb = max_bytes;
    if (mb == 0) mb = kDefaultMaxBytes;
    if (mb > kHardMaxBytes) mb = kHardMaxBytes;

    const st = std.fs.cwd().stat(path) catch return errorToJson(allocator, "not_found");
    if (st.kind != .file) return errorToJson(allocator, "not_file");

    const size = st.size;
    var f = std.fs.cwd().openFile(path, .{}) catch return errorToJson(allocator, "unreadable");
    defer f.close();

    const want = if (size < mb) @as(usize, size) else mb;
    var buf = try allocator.alloc(u8, want);
    defer allocator.free(buf);

    const n = f.read(buf) catch return errorToJson(allocator, "unreadable");
    buf = buf[0..n];

    // Binary sniff: a NUL byte means "not text" — report metadata only.
    if (std.mem.indexOfScalar(u8, buf, 0) != null) {
        return try std.fmt.allocPrint(allocator,
            "{\"path\":\"{s}\",\"size\":{},\"binary\":true}",
            .{path, size});
    }

    // Plain line split (\n terminated, tolerates \r\n)
    var lines_json = std.ArrayList(u8).init(allocator);
    defer lines_json.deinit();
    var line_count: usize = 0;
    var start: usize = 0;
    while (start <= buf.len) {
        const end = std.mem.indexOfScalar(u8, buf[start..], '\n') orelse buf.len;
        const last = (end == buf.len);
        var line = buf[start..start + end];
        if (line.len > 0 and line[line.len - 1] == '\r') line = line[0..line.len - 1];
        if (line_count > 0) try lines_json.appendSlice(",");
        const line_escaped = core.json_util.jsonEscape(allocator, line) catch continue;
        defer allocator.free(line_escaped);
        try std.fmt.bufPrintZ(&lines_json, "\"{s}\"", .{line_escaped});
        line_count += 1;
        if (last) break;
        start += end + 1;
    }

    const truncated = size > mb;
    return try std.fmt.allocPrint(allocator,
        "{\"path\":\"{s}\",\"size\":{},\"truncated\":{s},\"line_count\":{},\"lines\":[{s}]}",
        .{path, size, if (truncated) "true" else "false", line_count, lines_json.items});
}

pub export fn wayer_read_text_file(path: [*c]const u8, max_bytes: u64) [*c]const u8 {
    const allocator = std.heap.page_allocator;
    const json = readTextFile(allocator, std.mem.span(path), @as(usize, max_bytes)) catch return errorToCStr(allocator, "read_failed");
    return std.mem.toNullTerminated(allocator, json) catch "";
}

fn errorToJson(allocator: std.mem.Allocator, reason: []const u8) ![]u8 {
    return try std.fmt.allocPrint(allocator, "{{\"error\":\"{s}\"}}", .{reason});
}

fn errorToCStr(allocator: std.mem.Allocator, reason: []const u8) [*c]const u8 {
    const err = try std.fmt.allocPrint(allocator, "{{\"status\":\"error\",\"reason\":\"{s}\"}}", .{reason}) catch return "";
    return std.mem.toNullTerminated(allocator, err) catch "";
}