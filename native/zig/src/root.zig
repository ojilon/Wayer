// wayer_core.zig — Zig entry package (router + C ABI exports)
// This replaces native/odin/wayer_core.odin
// Imports all Zig modules and routes actions from JNI

const std = @import("std");

// Import all Zig modules
const core = @import("core");
const storage = @import("storage");
const search = @import("search");
const large_files = @import("large_files");
const duplicate_finder = @import("duplicate_finder");
const organizer = @import("organizer");
const documents = @import("documents");
const transfer = @import("transfer");
const preview = @import("preview");
const media = @import("media");

// Thread-local reply buffer for C ABI (matching Odin pattern)
var reply_buffer: [16384]u8 = undefined;

fn reply(s: []const u8) [*c]const u8 {
    const n = @min(s.len, reply_buffer.len - 1);
    @memcpy(reply_buffer[0..n], s[0..n]);
    reply_buffer[n] = 0;
    return &reply_buffer[0];
}

// C string helper - clone to NUL-terminated
fn cs(allocator: std.mem.Allocator, s: []const u8) !*[*:0]const u8 {
    return std.cstr.fromSlice(allocator, s);
}

// Action IDs — must stay identical to NativeEngine.java
const ACTION_PING = 1;
const ACTION_GET_STATUS = 2;
const ACTION_LIST_FILES = 3;
const ACTION_GET_NETWORK_INFO = 4;
const ACTION_FILTER_DOCUMENTS = 5;
const ACTION_START_LISTENER = 6;
const ACTION_SEARCH_FILES = 8;
const ACTION_FIND_LARGE_FILES = 9;
const ACTION_FIND_DUPLICATES = 10;
const ACTION_PLAN_ORGANIZE = 11;
const ACTION_APPLY_ORGANIZE = 12;
const ACTION_GET_CACHED_STATS = 13;
const ACTION_INIT_APP_PATHS = 14;
const ACTION_BUILD_INDEX = 15;
const ACTION_INVALIDATE_CACHE = 16;
const ACTION_INDEX_META = 17;
const ACTION_SEARCH_INDEX = 18;
const ACTION_READ_TEXT_FILE = 19;
const ACTION_GROUP_INDEX_BY_DAY = 21;

const BAD_PAYLOAD = "{\"status\":\"error\",\"reason\":\"bad_payload\"}";

// --- String utilities ---

fn allDigits(s: []const u8) bool {
    if (s.len == 0) return false;
    for (s) |ch| {
        if (ch < '0' or ch > '9') return false;
    }
    return true;
}

fn splitPayload(allocator: std.mem.Allocator, payload: []const u8) ![][*:0]u8 {
    var parts = std.ArrayList([]u8).init(allocator);
    defer parts.deinit();

    var start: usize = 0;
    for (payload, 0..) |_, i| {
        if (payload[i] == '|') {
            try parts.append(payload[start..i]);
            start = i + 1;
        }
    }
    try parts.append(payload[start..]);

    var c_parts = std.ArrayList([*:0]u8).init(allocator);
    defer c_parts.deinit();

    for (parts.items) |part| {
        const cstr = try std.cstr.fromSlice(allocator, part);
        try c_parts.append(cstr);
    }

    return c_parts.toOwnedSlice();
}

fn joinParts(allocator: std.mem.Allocator, parts: [][]const u8, sep: []const u8) ![]u8 {
    return std.mem.join(allocator, parts, sep);
}

fn splitTrailingNumber(payload: []const u8, default_value: u64) struct { text: []const u8, number: u64 } {
    const text = payload;
    const number = default_value;
    const pos = std.mem.lastIndexByte(payload, '|') orelse return .{ .text = text, .number = number };
    const tail = payload[pos + 1 ..];
    if (!allDigits(tail)) return .{ .text = text, .number = number };
    const parsed = std.fmt.parseInt(u64, tail, 10) catch return .{ .text = text, .number = number };
    return .{ .text = payload[0..pos], .number = parsed };
}

// --- Router ---

fn initAppPaths(allocator: std.mem.Allocator, raw: []const u8) [*c]const u8 {
    var root = std.mem.trimRight(u8, raw, "\n\r \t/");
    if (root.len == 0) return reply(BAD_PAYLOAD);
    if (!std.mem.endsWith(u8, root, "/wayer")) {
        root = try std.mem.join(allocator, .{root, "/wayer"}, "");
    }
    const c_root = try cs(allocator, root);
    return core.paths.setAppPaths(c_root);
}

export fn wayer_route_action(action_id: c_int, payload: [*c]const u8) [*c]const u8 {
    const allocator = std.heap.page_allocator;
    const payload_str = std.mem.span(payload);
    defer std.heap.page_allocator.free(allocator);

    switch (action_id) {
        ACTION_PING => {
            const msg = try std.fmt.allocPrint(allocator, "PONG: {s}", .{payload_str});
            defer allocator.free(msg);
            return reply(msg);
        },
        ACTION_GET_STATUS => {
            return reply("{\"status\": \"ready\", \"engine\": \"Zig\"}");
        },
        ACTION_LIST_FILES => {
            const json = storage.walker.listFiles(allocator, payload_str) catch return reply(BAD_PAYLOAD);
            defer allocator.free(json);
            return reply(json);
        },
        ACTION_GET_NETWORK_INFO => {
            return transfer.getNetworkInfo() catch return reply(BAD_PAYLOAD);
        },
        ACTION_FILTER_DOCUMENTS => {
            return documents.filterDocuments(payload_str) catch return reply(BAD_PAYLOAD);
        },
        ACTION_START_LISTENER => {
            return transfer.startListener(8080) catch return reply(BAD_PAYLOAD);
        },
        ACTION_SEARCH_FILES => {
            const parts = splitPayload(allocator, payload_str) catch return reply(BAD_PAYLOAD);
            defer {
                for (parts) |p| allocator.free(p);
            }
            if (parts.len < 3 || (parts[1].len == 0)) return reply(BAD_PAYLOAD);
            const query = try joinParts(allocator, parts[2..], "|");
            defer allocator.free(query);
            return search.searchFilesToFile(
                cs(allocator, parts[0]) catch return reply(BAD_PAYLOAD),
                cs(allocator, query) catch return reply(BAD_PAYLOAD),
                cs(allocator, parts[1]) catch return reply(BAD_PAYLOAD),
            );
        },
        ACTION_FIND_LARGE_FILES => {
            const parts = splitPayload(allocator, payload_str) catch return reply(BAD_PAYLOAD);
            defer {
                for (parts) |p| allocator.free(p);
            }
            if (parts.len < 4 || (parts[3].len == 0)) return reply(BAD_PAYLOAD);
            var root = parts[0];
            if (root.len == 0) root = "/storage/emulated/0";
            var min_bytes: u64 = 10 * 1024 * 1024;
            var max_results: c_int = 50;
            if (parts[1].len > 0) {
                min_bytes = std.fmt.parseInt(u64, parts[1], 10) catch min_bytes;
            }
            if (parts[2].len > 0) {
                max_results = @intCast(std.fmt.parseInt(i64, parts[2], 10) catch max_results);
            }
            return large_files.findLargeFilesToFile(
                cs(allocator, root) catch return reply(BAD_PAYLOAD),
                min_bytes,
                max_results,
                cs(allocator, parts[3]) catch return reply(BAD_PAYLOAD),
            );
        },
        ACTION_FIND_DUPLICATES => {
            const parts = splitPayload(allocator, payload_str) catch return reply(BAD_PAYLOAD);
            defer {
                for (parts) |p| allocator.free(p);
            }
            if (parts.len < 2 || (parts[1].len == 0)) return reply(BAD_PAYLOAD);
            return duplicate_finder.findDuplicatesToFile(
                cs(allocator, parts[0]) catch return reply(BAD_PAYLOAD),
                cs(allocator, parts[1]) catch return reply(BAD_PAYLOAD),
            );
        },
        ACTION_PLAN_ORGANIZE => {
            const parts = splitPayload(allocator, payload_str) catch return reply(BAD_PAYLOAD);
            defer {
                for (parts) |p| allocator.free(p);
            }
            if (parts.len < 2 || (parts[1].len == 0)) return reply(BAD_PAYLOAD);
            return organizer.planOrganizeToFile(
                cs(allocator, parts[0]) catch return reply(BAD_PAYLOAD),
                cs(allocator, parts[1]) catch return reply(BAD_PAYLOAD),
            );
        },
        ACTION_APPLY_ORGANIZE => {
            const parts = splitPayload(allocator, payload_str) catch return reply(BAD_PAYLOAD);
            defer {
                for (parts) |p| allocator.free(p);
            }
            if (parts.len < 2 || (parts[0].len == 0) || (parts[1].len == 0)) return reply(BAD_PAYLOAD);
            return organizer.applyOrganizeFile(
                cs(allocator, parts[0]) catch return reply(BAD_PAYLOAD),
                cs(allocator, parts[1]) catch return reply(BAD_PAYLOAD),
            );
        },
        ACTION_GET_CACHED_STATS => {
            const parts = splitPayload(allocator, payload_str) catch return reply(BAD_PAYLOAD);
            defer {
                for (parts) |p| allocator.free(p);
            }
            if (parts.len < 3) return reply(BAD_PAYLOAD);
            const max_age = std.fmt.parseInt(c_int, parts[2], 10) catch 0;

            const cached = storage.storage_cache.readCacheIfFresh(allocator, std.mem.span(parts[0]), max_age) catch return reply(BAD_PAYLOAD);
            if (cached.len > 0) {
                const escaped = core.json_util.jsonEscape(allocator, std.mem.span(parts[0])) catch return reply(BAD_PAYLOAD);
                defer allocator.free(escaped);
                const msg = try std.fmt.allocPrint(allocator, "{\"status\":\"ok\",\"path\":\"{s}\"}", .{escaped});
                defer allocator.free(msg);
                return reply(msg);
            }

            var known_bytes: u64 = 0;
            if (parts.len > 3) {
                known_bytes = std.fmt.parseInt(u64, parts[3], 10) catch 0;
            }
            return storage.analyse_storage_space.writeStorageStats(
                cs(allocator, parts[1]) catch return reply(BAD_PAYLOAD),
                cs(allocator, parts[0]) catch return reply(BAD_PAYLOAD),
                known_bytes,
            );
        },
        ACTION_INIT_APP_PATHS => {
            return initAppPaths(allocator, payload_str);
        },
        ACTION_BUILD_INDEX => {
            const parts = splitPayload(allocator, payload_str) catch return reply(BAD_PAYLOAD);
            defer {
                for (parts) |p| allocator.free(p);
            }
            if (parts.len < 2 || (parts[0].len == 0) || (parts[1].len == 0)) return reply(BAD_PAYLOAD);
            return storage.index.buildIndex(
                cs(allocator, parts[0]) catch return reply(BAD_PAYLOAD),
                cs(allocator, parts[1]) catch return reply(BAD_PAYLOAD),
            );
        },
        ACTION_INDEX_META => {
            if (payload_str.len == 0) return reply(BAD_PAYLOAD);
            return storage.index.indexMeta(cs(allocator, payload_str) catch return reply(BAD_PAYLOAD));
        },
        ACTION_SEARCH_INDEX => {
            const parts = splitPayload(allocator, payload_str) catch return reply(BAD_PAYLOAD);
            defer {
                for (parts) |p| allocator.free(p);
            }
            if (parts.len < 2 || (parts[0].len == 0) || (parts[1].len == 0)) return reply(BAD_PAYLOAD);

            var max_results: u64 = 50;
            var query_from: usize = 2;
            if (parts.len > 2 and allDigits(parts[2])) {
                max_results = std.fmt.parseInt(u64, parts[2], 10) catch 50;
                query_from = 3;
            }
            var query: []const u8 = "";
            if (query_from < parts.len) {
                query = try joinParts(allocator, parts[query_from..], "|");
                defer allocator.free(query);
            }
            return storage.index.searchIndexToFile(
                cs(allocator, query) catch return reply(BAD_PAYLOAD),
                max_results,
                cs(allocator, parts[0]) catch return reply(BAD_PAYLOAD),
                cs(allocator, parts[1]) catch return reply(BAD_PAYLOAD),
            );
        },
        ACTION_READ_TEXT_FILE => {
            const result = splitTrailingNumber(payload_str, 0);
            const path = result.text;
            const max_bytes = result.number;
            return preview.readTextFile(
                cs(allocator, path) catch return reply(BAD_PAYLOAD),
                max_bytes,
            );
        },
        ACTION_INVALIDATE_CACHE => {
            if (storage.storage_cache.invalidateCache(std.mem.span(payload_str))) {
                return reply("{\"status\":\"invalidated\"}");
            }
            return reply("{\"status\":\"missing\"}");
        },
        ACTION_GROUP_INDEX_BY_DAY => {
            const parts = splitPayload(allocator, payload_str) catch return reply(BAD_PAYLOAD);
            defer {
                for (parts) |p| allocator.free(p);
            }
            if (parts.len < 2 || (parts[0].len == 0) || (parts[1].len == 0)) return reply(BAD_PAYLOAD);
            var max_days: c_int = 14;
            var max_per_day: c_int = 50;
            if (parts.len > 2) {
                max_days = std.fmt.parseInt(c_int, parts[2], 10) catch 14;
            }
            if (parts.len > 3) {
                max_per_day = std.fmt.parseInt(c_int, parts[3], 10) catch 50;
            }
            return storage.index.groupIndexByDay(
                cs(allocator, parts[1]) catch return reply(BAD_PAYLOAD),
                cs(allocator, parts[0]) catch return reply(BAD_PAYLOAD),
                max_days,
                max_per_day,
            );
        },
        else => {
            core.logging.logError("WayerEngine", "unknown action from Java");
            return reply("{\"error\": \"unknown_action\"}");
        },
    }
}

export fn wayer_init_engine() void {
    core.logging.info("WayerEngine", "Zig engine initialized");
}