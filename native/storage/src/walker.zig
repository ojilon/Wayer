// wayer_storage — shared walk primitive.
// Ported from native/storage/src/walker.cpp / walker.odin
// Uses C bridge (dir_walk_android.c) for Android compatibility (no statx).

const std = @import("std");
const safety = @import("safety.zig");
const extension_map = @import("extension_map.zig");

// Re-export Category enum for consumers
pub const Category = extension_map.Category;

// C bridge (dir_walk_android.c) — no statx, uses opendir/readdir/stat
extern "c" fn wayer_dir_open(path: [*c]const u8) *anyopaque;
extern "c" fn wayer_dir_next(dir: *anyopaque, out: *WayerDirEntry) c_int;
extern "c" fn wayer_dir_close(dir: *anyopaque) void;

pub const WayerDirEntry = extern struct {
    name: [*c]const u8,
    name_len: usize,
    is_dir: c_int,    // 1 dir, 0 file, -1 other
    size: i64,
};

/// Everything the walk accumulates.
pub const Scan = struct {
    categories: [Category.count]u64,
    top_dirs: std.StringHashMap(u64),

    pub fn init(allocator: std.mem.Allocator) Scan {
        var scan: Scan = undefined;
        // Initialize categories array to zeros
        for (&scan.categories) |*c| c.* = 0;
        scan.top_dirs = std.StringHashMap(u64).init(allocator);
        return scan;
    }

    pub fn deinit(self: *Scan) void {
        self.top_dirs.deinit();
    }
};

/// `top` is the name of the top-level folder we are inside.
/// "" means we're directly in the root, so files here count toward categories only.
pub fn scanDir(allocator: std.mem.Allocator, scan: *Scan, dir: []const u8, top: []const u8) !void {
    const c_dir = try std.cstr.fromSlice(allocator, dir);
    defer allocator.free(c_dir);

    const handle = wayer_dir_open(c_dir);
    if (handle == null) return; // unreadable, same as old error_code skip
    defer wayer_dir_close(handle);

    var ent: WayerDirEntry = undefined;
    while (wayer_dir_next(handle, &ent) != 0) {
        // name from C is a cstring; take exact length
        const name = std.mem.span(ent.name)[0..@intCast(ent.name_len)];

        if (ent.is_dir == 1) {
            if (safety.isExcludedDir(name, dir)) continue;
            const child = try std.fmt.allocPrint(allocator, "{s}/{s}", .{dir, name});
            defer allocator.free(child);
            const child_top = if (top.len == 0) name else top;
            try scanDir(allocator, scan, child, child_top);
            continue;
        }

        if (ent.is_dir != 0) continue; // not a regular file

        const size = if (ent.size > 0) @as(u64, @intCast(ent.size)) else 0;
        const cat = extension_map.categoryForName(name);
        scan.categories[cat] += size;

        if (top.len != 0) {
            if (!scan.top_dirs.fetch(top).found) {
                _ = scan.top_dirs.put(try allocator.dupe(u8, top), 0) catch {};
            }
            scan.top_dirs.getPtr(top).? += size;
        }
    }
}

/// Non-recursive directory listing for list_files action
pub fn listFiles(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const c_path = try std.cstr.fromSlice(allocator, path);
    defer allocator.free(c_path);

    const handle = wayer_dir_open(c_path);
    if (handle == null) {
        const err = try std.fmt.allocPrint(allocator, "{\"error\":\"invalid_directory\"}");
        return err;
    }
    defer wayer_dir_close(handle);

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    try buf.appendSlice("{\"files\":[");

    var first = true;
    var ent: WayerDirEntry = undefined;
    while (wayer_dir_next(handle, &ent) != 0) {
        const name = std.mem.span(ent.name)[0..@intCast(ent.name_len)];
        if (!first) try buf.appendSlice(",");
        first = false;

        const json = @import("../core/src/json_util.zig");
        const escaped = try json.jsonEscape(allocator, name);
        defer allocator.free(escaped);
        try buf.appendSlice("\"");
        try buf.appendSlice(escaped);
        try buf.appendSlice("\"");
    }
    try buf.appendSlice("]}");
    return buf.toOwnedSlice();
}