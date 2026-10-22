// wayer_storage — directory exclusion rules.
// Ported from native/storage/src/safety.cpp / safety.odin

const std = @import("std");

/// Returns true if the directory should be skipped during scanning.
pub fn isExcludedDir(name: []const u8, parent: []const u8) bool {
    // Android private data — never scan (scoped storage denies most anyway).
    if (std.mem.eql(u8, name, "data") or std.mem.eql(u8, name, "obb")) {
        if (std.mem.endsWith(u8, parent, "/Android")) return true;
    }
    // Thumbnails / caches / trash — scanning wastes time, deleting risks system files.
    if (std.mem.eql(u8, name, ".thumbnails") or std.mem.eql(u8, name, "thumbnails") or
        std.mem.eql(u8, name, ".trashed") or std.mem.eql(u8, name, ".trash") or
        std.mem.eql(u8, name, ".cache") or std.mem.eql(u8, name, "LOST.DIR")) {
        return true;
    }
    // App's own scratch + holding folder (see FileMutator.moveToTrash).
    // Keeps scans from finding their own output / staged deletes.
    if (std.mem.eql(u8, name, ".dwayer_cache") or std.mem.eql(u8, name, "wayer_trash") or
        std.mem.eql(u8, name, ".wayer_trash")) {
        return true;
    }
    // NOTE: hardlinks (same inode, two paths) are NOT skipped here — detecting
    // them needs fs::equivalent(a,b) per pair (slow). They may still appear as
    // duplicates but save 0 bytes; UI labels them via size+mtime instead.
    return false;
}