const std = @import("std");
const builtin = @import("builtin");

const RETAIL_64GB: u64 = 64_000_000_000;
const kMaxFolders: usize = 100;

// statvfs from libc (bionic, LP64 layout)
const Statvfs = extern struct {
    f_bsize:   c_ulong,
    f_frsize:  c_ulong,
    f_blocks:  c_ulong,
    f_bfree:   c_ulong,
    f_bavail:  c_ulong,
    f_files:   c_ulong,
    f_ffree:   c_ulong,
    f_favail:  c_ulong,
    f_fsid:    c_ulong,
    f_flag:    c_ulong,
    f_namemax: c_ulong,
    _reserved: [6]u32,
};

extern "c" fn statvfs(path: [*c]const u8, buf: *Statvfs) c_int;

// Category enum
const Category = enum(u8) {
    Images,
    Videos,
    Audio,
    Documents,
    Foreign_Files,
    Others,
};

const FolderStat = struct {
    name: []u8,
    bytes: u64,
};

const Scan = struct {
    categories: [Category.count]u64,
    top_dirs: std.StringHashMap(u64),
};

fn kindFromExt(name: []const u8) Category {
    const dot = std.mem.lastIndexByte(name, '.') orelse return Category.Others;
    const ext = std.ascii.lower(name[dot + 1..]);
    
    if (std.mem.eql(u8, ext, "jpg") or std.mem.eql(u8, ext, "jpeg") or std.mem.eql(u8, ext, "png") or
        std.mem.eql(u8, ext, "webp") or std.mem.eql(u8, ext, "gif") or std.mem.eql(u8, ext, "heic") or
        std.mem.eql(u8, ext, "bmp")) {
        return Category.Images;
    }
    if (std.mem.eql(u8, ext, "mp4") or std.mem.eql(u8, ext, "mkv") or std.mem.eql(u8, ext, "avi") or
        std.mem.eql(u8, ext, "webm") or std.mem.eql(u8, ext, "3gp") or std.mem.eql(u8, ext, "mov")) {
        return Category.Videos;
    }
    if (std.mem.eql(u8, ext, "mp3") or std.mem.eql(u8, ext, "wav") or std.mem.eql(u8, ext, "flac") or
        std.mem.eql(u8, ext, "m4a") or std.mem.eql(u8, ext, "ogg") or std.mem.eql(u8, ext, "aac")) {
        return Category.Audio;
    }
    if (std.mem.eql(u8, ext, "pdf") or std.mem.eql(u8, ext, "txt") or std.mem.eql(u8, ext, "doc") or
        std.mem.eql(u8, ext, "docx") or std.mem.eql(u8, ext, "xls") or std.mem.eql(u8, ext, "xlsx") or
        std.mem.eql(u8, ext, "md") or std.mem.eql(u8, ext, "py") or std.mem.eql(u8, ext, "csv")) {
        return Category.Documents;
    }
    if (std.mem.eql(u8, ext, "apk") or std.mem.eql(u8, ext, "obb")) {
        return Category.Foreign_Files;
    }
    return Category.Others;
}

fn isExcludedName(name: []const u8, parent_name: ?[]const u8) bool {
    if (std.mem.eql(u8, name, ".thumbnails") or std.mem.eql(u8, name, "thumbnails")) return true;
    if (std.mem.eql(u8, name, ".trashed") or std.mem.eql(u8, name, ".trash")) return true;
    if (std.mem.eql(u8, name, ".cache") or std.mem.eql(u8, name, "LOST.DIR")) return true;
    if (std.mem.eql(u8, name, ".dwayer_cache") or std.mem.eql(u8, name, "wayer_trash") or std.mem.eql(u8, name, ".wayer_trash")) return true;
    if (std.mem.eql(u8, name, "data") and (parent_name.? != null and std.mem.eql(u8, parent_name.?, "Android"))) return true;
    if (std.mem.eql(u8, name, "obb") and (parent_name.? != null and std.mem.eql(u8, parent_name.?, "Android"))) return true;
    return false;
}

fn parentFolderName(path: []const u8) []const u8 {
    const slash = std.mem.lastIndexByte(path, '/') orelse return "";
    if (slash == 0) return "";
    var start = slash;
    while (start > 0 and path[start - 1] != '/') : (start -= 1) {}
    return path[start..slash];
}

fn basename(path: []const u8) []const u8 {
    const slash = std.mem.lastIndexByte(path, '/') orelse return path;
    return path[slash + 1..];
}

fn scanDir(allocator: std.mem.Allocator, scan: *Scan, dir: []const u8, root: []const u8) !void {
    var iter = try std.fs.cwd().iterateDir(dir);
    defer iter.deinit();
    
    const parent_name = parentFolderName(dir);
    
    while (try iter.next()) |entry| {
        if (entry.name[0] == '.' and (entry.name.len == 1 or (entry.name.len == 2 and entry.name[1] == '.'))) continue;
        
        if (isExcludedName(entry.name, if (parent_name.len > 0) parent_name else null)) continue;
        
        const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{dir, entry.name});
        defer allocator.free(full_path);
        
        const st = try std.fs.cwd().stat(full_path);
        
        if (st.kind == .dir) {
            try scanDir(allocator, scan, full_path, root);
            continue;
        }
        
        if (st.kind != .file) continue;
        
        const kind = kindFromExt(entry.name);
        scan.categories[kind] += st.size;
        
        // Track top-level folder
        if (root.len > 0) {
            const rel = full_path[root.len + 1..];
            const top_slash = std.mem.indexOf(u8, rel, "/") orelse rel.len;
            const top_dir = rel[0..top_slash];
            const current = scan.top_dirs.getOrDefault(top_dir, 0);
            scan.top_dirs.put(top_dir, current + st.size) catch {};
        }
    }
}

fn jsonEscape(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    
    for (s) |ch| {
        switch (ch) {
            '"' => try buf.appendSlice("\\\""),
            '\\' => try buf.appendSlice("\\\\"),
            '\n' => try buf.appendSlice("\\n"),
            '\r' => try buf.appendSlice("\\r"),
            '\t' => try buf.appendSlice("\\t"),
            else => if (ch < 0x20) {
                try buf.appendSlice("\\u");
                try std.fmt.bufPrintZ(&buf, "{0>04x}", .{@intCast(ch)});
            } else {
                try buf.append(ch);
            },
        }
    }
    return buf.toOwnedSlice();
}

fn buildStatsJson(allocator: std.mem.Allocator, total: u64, used: u64, free: u64, progress: u8,
    images: u64, videos: u64, audio: u64, documents: u64, foreign: u64, system: u64, others: u64,
    folders: []FolderStat) ![]u8 {
    
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    
    try buf.appendSlice("{\"total_bytes\":");
    try std.fmt.bufPrintZ(&buf, "{}", .{total});
    try buf.appendSlice(",\"used_bytes\":");
    try std.fmt.bufPrintZ(&buf, "{}", .{used});
    try buf.appendSlice(",\"free_bytes\":");
    try std.fmt.bufPrintZ(&buf, "{}", .{free});
    try buf.appendSlice(",\"progress_percent\":");
    try std.fmt.bufPrintZ(&buf, "{}", .{progress});
    try buf.appendSlice(",\"images\":");
    try std.fmt.bufPrintZ(&buf, "{}", .{images});
    try buf.appendSlice(",\"videos\":");
    try std.fmt.bufPrintZ(&buf, "{}", .{videos});
    try buf.appendSlice(",\"audio\":");
    try std.fmt.bufPrintZ(&buf, "{}", .{audio});
    try buf.appendSlice(",\"documents\":");
    try std.fmt.bufPrintZ(&buf, "{}", .{documents});
    try buf.appendSlice(",\"foreign_files\":");
    try std.fmt.bufPrintZ(&buf, "{}", .{foreign});
    try buf.appendSlice(",\"system\":");
    try std.fmt.bufPrintZ(&buf, "{}", .{system});
    try buf.appendSlice(",\"others\":");
    try std.fmt.bufPrintZ(&buf, "{}", .{others});
    try buf.appendSlice(",\"folders\":[");
    
    for (folders, 0..) |folder, i| {
        if (i > 0) try buf.appendSlice(",");
        try buf.appendSlice("{\"name\":\"");
        const escaped = try jsonEscape(allocator, folder.name);
        defer allocator.free(escaped);
        try buf.appendSlice(escaped);
        try buf.appendSlice("\",\"bytes\":");
        try std.fmt.bufPrintZ(&buf, "{}", .{folder.bytes});
        try buf.appendSlice("}");
    }
    
    try buf.appendSlice("]}");
    return buf.toOwnedSlice();
}

export fn wayer_write_storage_stats(root: [*c]const u8, out_path: [*c]const u8, known_device_bytes: u64) [*c]const u8 {
    const allocator = std.heap.page_allocator;
    const root_str = std.mem.span(root);
    const out_path_str = std.mem.span(out_path);
    
    // 1. Partition metrics from the OS
    var stat: Statvfs = undefined;
    const c_root = try std.cstr.fromSlice(allocator, root_str);
    defer allocator.free(c_root);
    
    if (statvfs(c_root, &stat) != 0) {
        const err = try std.fmt.allocPrint(allocator, "{\"status\":\"error\",\"reason\":\"statvfs_failed\"}");
        return std.mem.toNullTerminated(allocator, err) catch "";
    }
    
    const partition_total = @as(u64, @intCast(stat.f_blocks)) * @as(u64, @intCast(stat.f_frsize));
    const free_bytes = @as(u64, @intCast(stat.f_bavail)) * @as(u64, @intCast(stat.f_frsize));
    const partition_used = if (partition_total > free_bytes) partition_total - free_bytes else 0;
    
    // Prefer the real capacity from Java; otherwise fall back to the retail floor.
    var device_total = known_device_bytes;
    if (device_total == 0) {
        device_total = @max(partition_total, RETAIL_64GB);
    }
    device_total = @max(device_total, partition_total);
    
    const system_bytes = if (device_total > partition_total) device_total - partition_total else 0;
    const used_bytes = partition_used + system_bytes;
    
    // 2. One walk feeds both the category totals and the per-top-folder sizes
    var scan = Scan{
        .categories = undefined,
        .top_dirs = std.StringHashMap(u64).init(allocator),
    };
    // Initialize categories to 0
    for (&scan.categories) |*cat| cat.* = 0;
    defer scan.top_dirs.deinit();
    
    const root_trimmed = std.mem.trimRight(u8, root_str, "/");
    try scanDir(allocator, &scan, root_trimmed, root_trimmed);
    
    // 3. Top folders, biggest first, capped
    var folders = std.ArrayList(FolderStat).init(allocator);
    defer folders.deinit();
    
    var iter = scan.top_dirs.iterator();
    while (iter.next()) |entry| {
        try folders.append(FolderStat{
            .name = try allocator.dupe(u8, entry.key_ptr.*),
            .bytes = entry.value_ptr.*,
        });
    }
    
    std.sort.sort(FolderStat, folders.items, {}, struct {
        fn lessThan(a: FolderStat, b: FolderStat) bool {
            return a.bytes > b.bytes;
        }
    });
    
    const top_folders = if (folders.items.len > kMaxFolders) folders.items[0..kMaxFolders] else folders.items;
    
    // 4. Assemble the numbers
    const progress: u8 = if (device_total > 0) @intCast((used_bytes * 100) / device_total) else 0;
    
    const json = try buildStatsJson(
        allocator,
        device_total, used_bytes, free_bytes, progress,
        scan.categories[Category.Images],
        scan.categories[Category.Videos],
        scan.categories[Category.Audio],
        scan.categories[Category.Documents],
        scan.categories[Category.Foreign_Files],
        system_bytes,
        scan.categories[Category.Others],
        top_folders,
    );
    defer allocator.free(json);
    
    // Write the JSON snapshot to the cache path
    try std.fs.cwd().writeFile(out_path_str, json, .{});
    
    // Success: tell Java where the fresh snapshot lives
    const escaped_out = try jsonEscape(allocator, out_path_str);
    defer allocator.free(escaped_out);
    const msg = try std.fmt.allocPrint(allocator, "{\"status\":\"ok\",\"path\":\"{s}\"}", .{escaped_out});
    return std.mem.toNullTerminated(allocator, msg) catch "";
}