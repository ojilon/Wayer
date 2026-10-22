// wayer_storage_organizer — plan + apply organization moves.
// Ported from native/storage/modules/organizer/src/file_organizer.cpp

const std = @import("std");
const core = @import("../../core/src/core.zig");
const extension_map = @import("../extension_map.zig");
const walker = @import("../walker.zig");

const Move = struct {
    from: []u8,
    to: []u8,
};

/// Generate date bucket YYYY-MM from file modification time
fn dateBucket(path: []const u8) []const u8 {
    const st = std.fs.cwd().stat(path) orelse return "unknown-date";
    const tm = std.time.toTm(st.mtime) catch return "unknown-date";
    const year = tm.year + 1900;
    const month = tm.month + 1;
    const buf = try std.fmt.allocPrint(std.heap.page_allocator, "{04}-{02}", .{year, month});
    return buf;
}

const kMaxErrors = 100;

fn noteError(allocator: std.mem.Allocator, errors: *std.ArrayList([]u8), from: []const u8, reason: []const u8) !void {
    if (errors.items.len >= kMaxErrors) return;
    const entry = try std.fmt.allocPrint(allocator, "{\"from\":\"{s}\",\"reason\":\"{s}\"}", .{from, reason});
    errors.append(entry) catch {};
}

/// Plan organization moves
pub fn planOrganize(allocator: std.mem.Allocator, root_path: []const u8) ![]u8 {
    var json = std.ArrayList(u8).init(allocator);
    defer json.deinit();
    try json.appendSlice("{\"moves\":[");

    var first = true;

    var scan = walker.Scan.init(allocator);
    defer scan.deinit();

    const root_trimmed = std.mem.trimRight(u8, root_path, "/");
    walker.scanDir(allocator, &scan, root_trimmed, root_trimmed) catch {};

    // We need to iterate the actual files again for planning
    // The walker groups by category but we need individual file paths
    var iter = try std.fs.cwd().iterateDirRecursive(root_trimmed, .{});
    defer iter.deinit();

    while (try iter.next()) |entry| {
        const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{entry.path, entry.name});
        defer allocator.free(full_path);

        const st = std.fs.cwd().stat(full_path) catch continue;
        if (st.kind != .file) continue;

        const ext = std.fs.path.ext(full_path);
        const category = extension_map.categoryForName(ext);
        const cat_name = switch (category) {
            extension_map.Category.Images => "images",
            extension_map.Category.Videos => "videos",
            extension_map.Category.Audio => "audio",
            extension_map.Category.Documents => "documents",
            extension_map.Category.Foreign_Files => "foreign",
            extension_map.Category.Others => "others",
        };

        // Only file types we actually recognize AND intend to relocate.
        // Images stay where they are for now (camera roll / DCIM conventions
        // need separate handling — see flags.md).
        if (std.mem.eql(u8, cat_name, "others") or std.mem.eql(u8, cat_name, "images")) continue;

        const bucket = dateBucket(full_path);
        const dest = try std.fmt.allocPrint(allocator, "{s}/{s}/{s}/{s}", .{root_path, cat_name, bucket, entry.name});
        defer allocator.free(dest);

        if (std.mem.eql(u8, dest, full_path)) continue;

        if (!first) try json.appendSlice(",");
        first = false;

        const from_escaped = core.json_util.jsonEscape(allocator, full_path) catch continue;
        defer allocator.free(from_escaped);
        const to_escaped = core.json_util.jsonEscape(allocator, dest) catch continue;
        defer allocator.free(to_escaped);
        try std.fmt.bufPrintZ(&json, "{\"from\":\"{s}\",\"to\":\"{s}\"}", .{from_escaped, to_escaped});
    }

    try json.appendSlice("]}");
    return json.toOwnedSlice();
}

/// Plan organize and write to file
pub export fn wayer_plan_organize_to_file(root: [*c]const u8, out_path: [*c]const u8) [*c]const u8 {
    const allocator = std.heap.page_allocator;
    const json = planOrganize(allocator, std.mem.span(root)) catch return errorToCStr(allocator, "plan_failed");
    defer allocator.free(json);

    core.text.writeTextFile(allocator, std.mem.span(out_path), json) catch return errorToCStr(allocator, "write_failed");

    const escaped = core.json_util.jsonEscape(allocator, std.mem.span(out_path)) catch return errorToCStr(allocator, "escape_failed");
    defer allocator.free(escaped);
    const msg = try std.fmt.allocPrint(allocator, "{\"status\":\"ok\",\"path\":\"{s}\"}", .{escaped}) catch return errorToCStr(allocator, "fmt_failed");
    return std.mem.toNullTerminated(allocator, msg) catch "";
}

/// Apply organization plan
pub export fn wayer_apply_organize_file(plan_path: [*c]const u8, report_path: [*c]const u8) [*c]const u8 {
    const allocator = std.heap.page_allocator;
    const plan_content = std.fs.cwd().readFileAlloc(allocator, std.mem.span(plan_path), 1024 * 1024) catch return errorToCStr(allocator, "bad_plan");
    defer allocator.free(plan_content);

    // Simple JSON parsing for moves array - we'll parse manually
    var moves = std.ArrayList(Move).init(allocator);
    defer moves.deinit();

    // Find "moves": [ ... ]
    const moves_start = std.mem.indexOf(u8, plan_content, "moves") orelse return errorToCStr(allocator, "bad_plan");
    const arr_start = std.mem.indexOfScalar(u8, plan_content[moves_start..], '[') orelse return errorToCStr(allocator, "bad_plan");
    const arr_end = std.mem.lastIndexByte(plan_content, ']') orelse return errorToCStr(allocator, "bad_plan");
    const moves_json = plan_content[moves_start + arr_start + 1 .. arr_end];

    // Parse each move object: {"from":"...","to":"..."}
    var pos: usize = 0;
    while (pos < moves_json.len) {
        // Find next {
        const obj_start = std.mem.indexOfScalar(u8, moves_json[pos..], '{') orelse break;
        pos += obj_start;
        const obj_end = std.mem.indexOfScalar(u8, moves_json[pos..], '}') orelse break;
        const obj = moves_json[pos..pos + obj_end + 1];
        pos += obj_end + 1;

        // Extract from and to
        const from_start = std.mem.indexOf(u8, obj, "\"from\"") orelse continue;
        const from_colon = std.mem.indexOfScalar(u8, obj[from_start..], ':') orelse continue;
        const from_quote1 = std.mem.indexOfScalar(u8, obj[from_start + from_colon..], '"') orelse continue;
        const from_quote2 = std.mem.indexOfScalar(u8, obj[from_start + from_colon + from_quote1 + 1..], '"') orelse continue;
        const from = obj[from_start + from_colon + from_quote1 + 1 .. from_start + from_colon + from_quote1 + 1 + from_quote2];

        const to_start = std.mem.indexOf(u8, obj, "\"to\"") orelse continue;
        const to_colon = std.mem.indexOfScalar(u8, obj[to_start..], ':') orelse continue;
        const to_quote1 = std.mem.indexOfScalar(u8, obj[to_start + to_colon..], '"') orelse continue;
        const to_quote2 = std.mem.indexOfScalar(u8, obj[to_start + to_colon + to_quote1 + 1..], '"') orelse continue;
        const to = obj[to_start + to_colon + to_quote1 + 1 .. to_start + to_colon + to_quote1 + 1 + to_quote2];

        moves.append(Move{
            .from = try allocator.dupe(u8, from),
            .to = try allocator.dupe(u8, to),
        }) catch {};
    }

    var moved: i32 = 0;
    var failed: i32 = 0;
    var skipped: i32 = 0;
    var errors = std.ArrayList([]u8).init(allocator);
    defer errors.deinit();

    for (moves.items) |move| {
        if (move.from.len == 0 or move.to.len == 0) {
            skipped += 1;
            continue;
        }

        const st = std.fs.cwd().stat(move.from) catch { skipped += 1; continue; };
        if (st.kind != .file) { skipped += 1; continue; }

        const to_parent = std.fs.path.dirname(move.to);
        if (to_parent.len > 0) {
            std.fs.cwd().makePath(to_parent, .{}) catch {
                failed += 1;
                _ = noteError(allocator, &errors, move.from, "mkdir_failed");
                continue;
            };
        }

        var dest = move.to;
        if (std.fs.cwd().exists(dest)) {
            // File exists, add _dup suffix
            const parent = std.fs.path.dirname(dest);
            const filename = std.fs.path.basename(dest);
            const stem = std.fs.path.basename(filename);
            const ext = std.fs.path.ext(filename);
            dest = try std.fmt.allocPrint(allocator, "{s}/{s}_dup{s}", .{parent, stem, ext});
            defer allocator.free(dest);
        }

        std.fs.cwd().rename(move.from, dest) catch {
            failed += 1;
            _ = noteError(allocator, &errors, move.from, "move_failed");
            continue;
        };
        moved += 1;
    }

    // Build report JSON
    var report = std.ArrayList(u8).init(allocator);
    defer report.deinit();

    try std.fmt.bufPrintZ(&report,
        "{\"moved\":{},\"failed\":{},\"skipped\":{},\"errors\":[",
        .{moved, failed, skipped});

    for (errors.items, 0..) |err, i| {
        if (i > 0) try report.appendSlice(",");
        try report.appendSlice(err);
    }
    try report.appendSlice("]}");

    core.text.writeTextFile(allocator, std.mem.span(report_path), report.items) catch return errorToCStr(allocator, "write_failed");

    const escaped = core.json_util.jsonEscape(allocator, std.mem.span(report_path)) catch return errorToCStr(allocator, "escape_failed");
    defer allocator.free(escaped);
    const msg = try std.fmt.allocPrint(allocator, "{\"status\":\"ok\",\"path\":\"{s}\"}", .{escaped}) catch return errorToCStr(allocator, "fmt_failed");
    return std.mem.toNullTerminated(allocator, msg) catch "";
}

fn errorToCStr(allocator: std.mem.Allocator, reason: []const u8) [*c]const u8 {
    const err = try std.fmt.allocPrint(allocator, "{{\"status\":\"error\",\"reason\":\"{s}\"}}", .{reason}) catch return "";
    return std.mem.toNullTerminated(allocator, err) catch "";
}