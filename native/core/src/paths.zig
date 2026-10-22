// wayer_core — AppPaths implementation.
// Ported from native/core/src/paths.cpp
// Manages app-owned directories under the path Java passes at init.

const std = @import("std");
const json_util = @import("json_util.zig");

pub const AppPaths = struct {
    root: []u8,
    cache: []u8,
    temp: []u8,
    logs: []u8,

    pub fn init() AppPaths {
        return AppPaths{
            .root = "",
            .cache = "",
            .temp = "",
            .logs = "",
        };
    }

    pub fn deinit(self: *AppPaths, allocator: std.mem.Allocator) void {
        allocator.free(self.root);
        allocator.free(self.cache);
        allocator.free(self.temp);
        allocator.free(self.logs);
    }
};

pub const DirEnsure = struct {
    path: []u8,
    existed: bool,
    ready: bool,

    pub fn init(allocator: std.mem.Allocator, path: []const u8) !DirEnsure {
        return DirEnsure{
            .path = try allocator.dupe(u8, path),
            .existed = false,
            .ready = false,
        };
    }

    pub fn deinit(self: *DirEnsure, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
    }
};

pub const AppDirsReport = struct {
    paths: AppPaths,
    root: DirEnsure,
    cache: DirEnsure,
    temp: DirEnsure,
    logs: DirEnsure,

    pub fn allReady(self: AppDirsReport) bool {
        return self.root.ready and self.cache.ready and self.temp.ready and self.logs.ready;
    }

    pub fn deinit(self: *AppDirsReport, allocator: std.mem.Allocator) void {
        self.paths.deinit(allocator);
        self.root.deinit(allocator);
        self.cache.deinit(allocator);
        self.temp.deinit(allocator);
        self.logs.deinit(allocator);
    }
};

// Internal: check-then-create for one directory
fn ensureOne(allocator: std.mem.Allocator, dir: []const u8) !DirEnsure {
    var d = try DirEnsure.init(allocator, dir);
    const st = std.fs.cwd().stat(dir) catch {
        d.existed = false;
        return d;
    };
    d.existed = st.kind == .dir;
    if (!d.existed) {
        try std.fs.cwd().makePath(dir, .{});
    }
    const st2 = std.fs.cwd().stat(dir) catch {
        d.ready = false;
        return d;
    };
    d.ready = st2.kind == .dir;
    return d;
}

// Check-then-create for root + cache/temp/logs. Safe to call on every init.
pub fn ensureAppDirs(allocator: std.mem.Allocator, app_root: []const u8) !AppDirsReport {
    var r: AppDirsReport = undefined;
    r.paths = AppPaths.init();
    r.paths.root = try allocator.dupe(u8, app_root);
    r.paths.cache = try std.fmt.allocPrint(allocator, "{s}/cache", .{app_root});
    r.paths.temp = try std.fmt.allocPrint(allocator, "{s}/temp", .{app_root});
    r.paths.logs = try std.fmt.allocPrint(allocator, "{s}/logs", .{app_root});

    r.root = try ensureOne(allocator, app_root);
    if (r.root.ready) {
        r.cache = try ensureOne(allocator, r.paths.cache);
        r.temp = try ensureOne(allocator, r.paths.temp);
        r.logs = try ensureOne(allocator, r.paths.logs);
    } else {
        r.cache = try DirEnsure.init(allocator, r.paths.cache);
        r.temp = try DirEnsure.init(allocator, r.paths.temp);
        r.logs = try DirEnsure.init(allocator, r.paths.logs);
    }
    return r;
}

fn boolJson(v: bool) []const u8 {
    return if (v) "true" else "false";
}

// Write <root>/paths.json manifest
pub fn writePathsManifest(allocator: std.mem.Allocator, report: AppDirsReport) ![]u8 {
    if (report.paths.root.len == 0 or !report.root.ready) return "";

    const manifest_path = try std.fmt.allocPrint(allocator, "{s}/paths.json", .{report.paths.root});
    defer allocator.free(manifest_path);

    const f = try std.fs.cwd().createFile(manifest_path, .{});
    defer f.close();

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    // Escape paths for JSON
    const root_escaped = try json_util.jsonEscape(allocator, report.paths.root);
    defer allocator.free(root_escaped);
    const cache_escaped = try json_util.jsonEscape(allocator, report.paths.cache);
    defer allocator.free(cache_escaped);
    const temp_escaped = try json_util.jsonEscape(allocator, report.paths.temp);
    defer allocator.free(temp_escaped);
    const logs_escaped = try json_util.jsonEscape(allocator, report.paths.logs);
    defer allocator.free(logs_escaped);

    const manifest_json = try std.fmt.allocPrint(allocator,
        "{{\"version\":1,\"root\":\"{s}\",\"dirs\":{{\"cache\":\"{s}\",\"temp\":\"{s}\",\"logs\":\"{s}\"}},\"existed\":{{\"root\":{s},\"cache\":{s},\"temp\":{s},\"logs\":{s}}},\"ready\":{{\"root\":{s},\"cache\":{s},\"temp\":{s},\"logs\":{s}}}}}",
        .{
            root_escaped, cache_escaped, temp_escaped, logs_escaped,
            boolJson(report.root.existed), boolJson(report.cache.existed),
            boolJson(report.temp.existed), boolJson(report.logs.existed),
            boolJson(report.root.ready), boolJson(report.cache.ready),
            boolJson(report.temp.ready), boolJson(report.logs.ready),
        });
    defer allocator.free(manifest_json);
    try f.writeAll(manifest_json);
    return manifest_path;
}

// Thread-safe global app paths (using std.Thread for thread-local if needed)
// For simplicity, we use a global mutex-protected state
var g_paths: AppPaths = AppPaths.init();
var g_initialized: bool = false;
const g_mutex = std.Thread.Mutex.init();

// Call once from JNI after Java supplies files dir.
pub fn setAppPaths(allocator: std.mem.Allocator, paths: AppPaths) !void {
    g_mutex.lock();
    defer g_mutex.unlock();
    g_paths.deinit(allocator);
    g_paths = AppPaths{
        .root = try allocator.dupe(u8, paths.root),
        .cache = try allocator.dupe(u8, paths.cache),
        .temp = try allocator.dupe(u8, paths.temp),
        .logs = try allocator.dupe(u8, paths.logs),
    };
    g_initialized = true;

    // Ensure directories exist even if caller built AppPaths manually.
    _ = std.fs.cwd().makePath(g_paths.cache, .{});
    _ = std.fs.cwd().makePath(g_paths.temp, .{});
    _ = std.fs.cwd().makePath(g_paths.logs, .{});
}

pub fn appPaths() AppPaths {
    g_mutex.lock();
    defer g_mutex.unlock();
    return g_paths;
}

pub fn appPathsInitialized() bool {
    g_mutex.lock();
    defer g_mutex.unlock();
    return g_initialized;
}

// C ABI exports for router
pub export fn wayer_init_app_paths(app_root: [*c]const u8) [*c]const u8 {
    const allocator = std.heap.page_allocator;
    const report = ensureAppDirs(allocator, std.mem.span(app_root)) catch {
        const err = try std.fmt.allocPrint(allocator, "{{\"error\":\"{s}\"}}", .{"init_failed"});
        return std.mem.toNullTerminated(allocator, err) catch "";
    };
    defer report.deinit(allocator);

    const manifest = writePathsManifest(allocator, report) catch {
        const err = try std.fmt.allocPrint(allocator, "{{\"error\":\"{s}\"}}", .{"manifest_failed"});
        return std.mem.toNullTerminated(allocator, err) catch "";
    };
    defer allocator.free(manifest);

    const json = try std.fmt.allocPrint(allocator,
        "{{\"status\":\"paths_set\",\"manifest\":\"{s}\",\"all_ready\":{s},\"root\":\"{s}\",\"cache\":\"{s}\",\"temp\":\"{s}\",\"logs\":\"{s}\"}}",
        .{manifest, if (report.allReady()) "true" else "false", report.paths.root, report.paths.cache, report.paths.temp, report.paths.logs});
    return std.mem.toNullTerminated(allocator, json) catch "";
}

pub export fn wayer_json_escape(s: [*c]const u8) [*c]const u8 {
    const allocator = std.heap.page_allocator;
    const escaped = json_util.jsonEscape(allocator, std.mem.span(s)) catch return "";
    return std.mem.toNullTerminated(allocator, escaped) catch "";
}