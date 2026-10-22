// wayer_storage — SQLite stats record.
// Ported from native/storage/src/stats_db.cpp
// Uses C sqlite3 from third_party/sqlite/sqlite3.c

const std = @import("std");
const core = @import("../core/src/core.zig");

extern "c" fn sqlite3_open(filename: [*c]const u8, ppDb: **anyopaque) c_int;
extern "c" fn sqlite3_close(db: *anyopaque) c_int;
extern "c" fn sqlite3_exec(db: *anyopaque, sql: [*c]const u8, callback: *anyopaque, arg: *anyopaque, errmsg: **u8) c_int;
extern "c" fn sqlite3_prepare_v2(db: *anyopaque, sql: [*c]const u8, nByte: c_int, ppStmt: **anyopaque, pzTail: **u8) c_int;
extern "c" fn sqlite3_bind_text(stmt: *anyopaque, index: c_int, text: [*c]const u8, n: c_int, destructor: *anyopaque) c_int;
extern "c" fn sqlite3_bind_int64(stmt: *anyopaque, index: c_int, value: i64) c_int;
extern "c" fn sqlite3_step(stmt: *anyopaque) c_int;
extern "c" fn sqlite3_finalize(stmt: *anyopaque) c_int;
extern "c" fn sqlite3_errmsg(db: *anyopaque) [*c]const u8;

const SQLITE_OK = 0;
const SQLITE_DONE = 101;
const SQLITE_TRANSIENT = -1;

/// Records storage stats snapshot to SQLite database
pub fn statsDbRecord(allocator: std.mem.Allocator, root: []const u8, total_bytes: u64, used_bytes: u64) !bool {
    if (root.len == 0 or !core.paths.appPathsInitialized()) return false;

    const cache_path = core.paths.appPaths().cache;
    if (cache_path.len == 0) return false;

    // Create stats directory
    const stats_dir = try std.fmt.allocPrint(allocator, "{s}/stats", .{cache_path});
    defer allocator.free(stats_dir);
    try std.fs.cwd().makePath(stats_dir, .{});

    const db_path = try std.fmt.allocPrint(allocator, "{s}/stats.db", .{stats_dir});
    defer allocator.free(db_path);

    var db: *anyopaque = null;
    const c_db_path = try std.cstr.fromSlice(allocator, db_path);
    defer allocator.free(c_db_path);

    if (sqlite3_open(c_db_path, &db) != SQLITE_OK) {
        sqlite3_close(db);
        return false;
    }
    defer sqlite3_close(db);

    // Create schema
    const schema = "CREATE TABLE IF NOT EXISTS stats_snapshots(root TEXT PRIMARY KEY, total_bytes INTEGER, used_bytes INTEGER, computed_unix INTEGER);";
    const c_schema = try std.cstr.fromSlice(allocator, schema);
    defer allocator.free(c_schema);

    if (sqlite3_exec(db, c_schema, null, null, null) != SQLITE_OK) {
        return false;
    }

    // Prepare insert
    const insert_sql = "INSERT OR REPLACE INTO stats_snapshots(root, total_bytes, used_bytes, computed_unix) VALUES(?, ?, ?, ?);";
    const c_insert_sql = try std.cstr.fromSlice(allocator, insert_sql);
    defer allocator.free(c_insert_sql);

    var stmt: *anyopaque = null;
    if (sqlite3_prepare_v2(db, c_insert_sql, -1, &stmt, null) != SQLITE_OK) {
        return false;
    }
    defer sqlite3_finalize(stmt);

    // Bind parameters
    const c_root = try std.cstr.fromSlice(allocator, root);
    defer allocator.free(c_root);

    if (sqlite3_bind_text(stmt, 1, c_root, -1, SQLITE_TRANSIENT) != SQLITE_OK) return false;
    if (sqlite3_bind_int64(stmt, 2, @as(i64, total_bytes)) != SQLITE_OK) return false;
    if (sqlite3_bind_int64(stmt, 3, @as(i64, used_bytes)) != SQLITE_OK) return false;

    const now: i64 = @as(i64, std.time.timestamp());
    if (sqlite3_bind_int64(stmt, 4, now) != SQLITE_OK) return false;

    if (sqlite3_step(stmt) != SQLITE_DONE) return false;

    return true;
}