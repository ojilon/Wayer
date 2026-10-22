// wayer_storage — file-backed cache for stats/index JSON blobs.
// Ported from native/storage/src/storage_cache.cpp

const std = @import("std");

/// Write JSON content to cache path (creating parents, truncating).
pub fn writeCache(_: std.mem.Allocator, cache_path: []const u8, json: []const u8) !void {
    const parent = std.fs.path.dirname(cache_path);
    if (parent.len > 0) {
        try std.fs.cwd().makePath(parent, .{});
    }
    const f = try std.fs.cwd().createFile(cache_path, .{});
    defer f.close();
    try f.writeAll(json);
}

/// Read cache if fresh (not older than max_age_seconds).
/// Returns empty slice if missing, stale, or error.
/// max_age_seconds <= 0 forces recompute.
pub fn readCacheIfFresh(allocator: std.mem.Allocator, cache_path: []const u8, max_age_seconds: i64) ![]u8 {
    if (max_age_seconds <= 0) return "";

    const st = std.fs.cwd().stat(cache_path) catch return "";
    if (st.kind != .file) return "";

    const now = std.time.timestamp();
    const age = now - st.mtime;
    if (age > max_age_seconds) return "";

    const content = try std.fs.cwd().readFileAlloc(allocator, cache_path, 1024 * 1024) catch return "";
    return content;
}

/// Invalidate (delete) cache file.
pub fn invalidateCache(cache_path: []const u8) bool {
    std.fs.cwd().deleteFile(cache_path) catch return false;
    return true;
}