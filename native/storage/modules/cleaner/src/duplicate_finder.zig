// wayer_storage_cleaner — duplicate detection (size → partial hash → full hash).
// Ported from native/storage/modules/cleaner/src/duplicate_finder.cpp
// v2 JSON: {"version":2,"duplicate_groups":[[{path,size,mtime}...]],"related_groups":[{key,files:[...]}]}

const std = @import("std");
const core = @import("../../core/src/core.zig");

const DupFile = struct {
    path: []u8,
    size: u64,
    mtime: i64, // unix seconds, 0 = unknown
};

// FNV-1a 64 over a byte stream — chunked, so multi-GB files never load fully.
fn fnv1aStream(file: std.fs.File, max_bytes: usize) u64 {
    const kOffset: u64 = 14695981039346656037;
    const kPrime: u64 = 1099511628211;
    var h: u64 = kOffset;
    var buf: [8192]u8 = undefined;
    var remaining = max_bytes;
    while (remaining > 0) {
        const want = @min(buf.len, remaining);
        const n = file.read(buf[0..want]) catch break;
        if (n == 0) break;
        for (buf[0..n]) |b| {
            h ^= b;
            h *= kPrime;
        }
        remaining -= n;
    }
    return h;
}

// Cheap partial hash: first 4 KiB mixed with size.
fn tryPartialHash(_: std.mem.Allocator, path: []const u8, size: u64, out: *u64) bool {
    const f = std.fs.cwd().openFile(path, .{}) catch return false;
    defer f.close();
    const h = fnv1aStream(f, 4096);
    out.* = h ^ (size * 0x9E3779B97F4A7C15);
    return true;
}

// Full hash
fn tryFullHash(_: std.mem.Allocator, path: []const u8, out: *u64) bool {
    const f = std.fs.cwd().openFile(path, .{}) catch return false;
    defer f.close();
    out.* = fnv1aStream(f, usize.MAX);
    return true;
}

// Byte-by-byte equality check
fn filesByteEqual(_: std.mem.Allocator, a: []const u8, b: []const u8) bool {
    const fa = std.fs.cwd().openFile(a, .{}) catch return false;
    defer fa.close();
    const fb = std.fs.cwd().openFile(b, .{}) catch return false;
    defer fb.close();

    var bufa: [8192]u8 = undefined;
    var bufb: [8192]u8 = undefined;
    while (true) {
        const na = fa.read(bufa[0..]) catch return false;
        const nb = fb.read(bufb[0..]) catch return false;
        if (na != nb) return false;
        if (na == 0) return true; // both hit end together
        if (!std.mem.eql(u8, bufa[0..na], bufb[0..nb])) return false;
    }
}

// Convert file time to unix seconds (NDK-safe)
fn fileMtimeUnix(path: []const u8) i64 {
    const st = std.fs.cwd().stat(path) orelse return 0;
    return st.mtime;
}

fn fileSizeOrZero(path: []const u8) u64 {
    const st = std.fs.cwd().stat(path) orelse return 0;
    return st.size;
}

// --- Related-files key: basic string ops only ---
fn endsWithWord(s: []const u8, word: []const u8) bool {
    if (s.len < word.len) return false;
    return std.mem.eql(u8, s[s.len - word.len..], word);
}

fn trimTrailingSpaceDash(s: []const u8, out: *std.ArrayList(u8)) void {
    var end = s.len;
    while (end > 0) {
        const c = s[end - 1];
        if (c == ' ' or c == '\t' or c == '-' or c == '_' or c == '.') {
            end -= 1;
        } else {
            break;
        }
    }
    out.clear();
    out.appendSlice(s[0..end]) catch {};
}

// "notes (1).docx" / "notes - final.docx" / "notes_v2.pdf" -> "notes"
// NEVER used for delete decisions — display grouping only.
fn normalizeRelatedKey(allocator: std.mem.Allocator, filename: []const u8) ![]u8 {
    var lower = std.ascii.lower(filename) catch return filename;
    defer allocator.free(lower);

    const dot = std.mem.lastIndexByte(lower, '.') orelse lower.len;
    const base = lower[0..dot];

    var cur = std.ArrayList(u8).init(allocator);
    defer cur.deinit();
    trimTrailingSpaceDash(base, &cur);

    for (0..5) |_| {
        var t = std.ArrayList(u8).init(allocator);
        trimTrailingSpaceDash(cur.items, &t);
        defer t.deinit();
        if (t.items.len == 0) {
            cur.clear();
            break;
        }
        // Trailing "(digits)" like " (1)" or "(12)"
        if (t.items.len > 0 and t.items[t.items.len - 1] == ')') {
            const open = std.mem.lastIndexByte(t.items, '(') orelse break;
            if (open + 1 < t.items.len) {
                var all_digits = true;
                for (t.items[open + 1 .. t.items.len - 1]) |ch| {
                    if (ch < '0' or ch > '9') { all_digits = false; break; }
                }
                if (all_digits) {
                    cur.items = cur.items[0..open];
                    continue;
                }
            }
            break;
        }
        if (endsWithWord(t.items, "copy")) {
            const pos = t.items.len - 4;
            if (pos > 0 and (t.items[pos - 1] == ' ' or t.items[pos - 1] == '-' or t.items[pos - 1] == '_' or t.items[pos - 1] == '(')) {
                cur.items = cur.items[0..pos - 1];
                continue;
            }
            break;
        }
        if (endsWithWord(t.items, "final")) {
            const pos = t.items.len - 5;
            if (pos > 0 and (t.items[pos - 1] == ' ' or t.items[pos - 1] == '-' or t.items[pos - 1] == '_')) {
                cur.items = cur.items[0..pos - 1];
                continue;
            }
            break;
        }
        // Trailing v-number: " v2", "_v2", "-v2", "v2"
        const n = t.items.len;
        var d = n;
        while (d > 0 and t.items[d - 1] >= '0' and t.items[d - 1] <= '9') d -= 1;
        if (d < n and d > 0 and (t.items[d - 1] == 'v' or t.items[d - 1] == 'V')) {
            const vpos = d - 1;
            if (vpos == 0) { cur.clear(); break; }
            const sep = t.items[vpos - 1];
            if (sep == ' ' or sep == '-' or sep == '_' or vpos == 0) {
                if (vpos > 0) {
                    cur.items = cur.items[0..vpos - (if (sep == ' ' or sep == '-' or sep == '_') 1 else 0)];
                } else {
                    cur.clear();
                }
                continue;
            }
        }
        break;
    }

    var done = std.ArrayList(u8).init(allocator);
    trimTrailingSpaceDash(cur.items, &done);
    return done.toOwnedSlice();
}

/// Find duplicates
pub fn findDuplicates(allocator: std.mem.Allocator, root_path: []const u8) ![]u8 {
    // Step 1: group by size
    var by_size = std.StringHashMap(std.ArrayList([]u8)).init(allocator);
    defer by_size.deinit();

    var iter = try std.fs.cwd().iterateDirRecursive(root_path, .{});
    defer iter.deinit();

    while (try iter.next()) |entry| {
        const full_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{entry.path, entry.name});
        const st = std.fs.cwd().stat(full_path) catch { allocator.free(full_path); continue; };
        if (st.kind != .file) { allocator.free(full_path); continue; }

        const sz = st.size;
        if (sz == 0) { allocator.free(full_path); continue; }

        var list = by_size.getOrCreate(sz) catch { allocator.free(full_path); continue; };
        if (!list) {
            list = std.ArrayList([]u8).init(allocator);
            by_size.put(sz, list.*) catch { allocator.free(full_path); continue; };
        }
        list.append(full_path) catch { allocator.free(full_path); continue; };
    }

    // Step 2: within each size group, group by partial hash
    var duplicate_groups = std.ArrayList(std.ArrayList(DupFile)).init(allocator);
    defer duplicate_groups.deinit();

    var by_size_iter = by_size.iterator();
    while (by_size_iter.next()) |size_entry| {
        const paths = size_entry.value_ptr.*;
        if (paths.items.len < 2) continue;

        var by_partial = std.StringHashMap(std.ArrayList([]u8)).init(allocator);
        defer by_partial.deinit();

        for (paths.items) |p| {
            var h: u64 = 0;
            if (!tryPartialHash(allocator, p, size_entry.key, &h)) continue;

            var list = by_partial.getOrCreate(h) catch continue;
            if (!list) {
                list = std.ArrayList([]u8).init(allocator);
                by_partial.put(h, list.*) catch continue;
            }
            list.append(p) catch {};
        }

        // Step 3: confirm with full hash only for partial-hash collisions
        var by_partial_iter = by_partial.iterator();
        while (by_partial_iter.next()) |partial_entry| {
            const candidates = partial_entry.value_ptr.*;
            if (candidates.items.len < 2) continue;

            var by_full = std.StringHashMap(std.ArrayList([]u8)).init(allocator);
            defer by_full.deinit();

            for (candidates.items) |p| {
                var h: u64 = 0;
                if (!tryFullHash(allocator, p, &h)) continue;

                var list = by_full.getOrCreate(h) catch continue;
                if (!list) {
                    list = std.ArrayList([]u8).init(allocator);
                    by_full.put(h, list.*) catch continue;
                }
                list.append(p) catch {};
            }

            var by_full_iter = by_full.iterator();
            while (by_full_iter.next()) |full_entry| {
                const same_hash = full_entry.value_ptr.*;
                if (same_hash.items.len < 2) continue;

                // Hash is only a hint: split by real byte content
                var verified = std.ArrayList(std.ArrayList([]u8)).init(allocator);
                defer verified.deinit();

                for (same_hash.items) |p| {
                    var placed = false;
                    for (verified.items) |v| {
                        if (filesByteEqual(allocator, v[0], p)) {
                            v.append(p) catch {};
                            placed = true;
                            break;
                        }
                    }
                    if (!placed) {
                        var v = std.ArrayList([]u8).init(allocator);
                        v.append(p) catch {};
                        verified.append(v) catch {};
                    }
                }

                for (verified.items) |v| {
                    if (v.items.len < 2) continue;
                    var group = std.ArrayList(DupFile).init(allocator);
                    defer group.deinit();
                    group.reserve(v.items.len) catch {};
                    for (v.items) |p| {
                        const f = DupFile{
                            .path = try allocator.dupe(u8, p),
                            .size = size_entry.key,
                            .mtime = fileMtimeUnix(p),
                        };
                        group.append(f) catch {};
                    }
                    duplicate_groups.append(group) catch {};
                }
            }
        }
    }

    // Sort groups
    for (duplicate_groups.items) |*g| {
        std.sort.sort(DupFile, g.items, {}, struct {
            fn lessThan(a: DupFile, b: DupFile) bool { return std.mem.lessThan(u8, a.path, b.path); }
        });
    }
    std.sort.sort(std.ArrayList(DupFile), duplicate_groups.items, {}, struct {
        fn lessThan(a: std.ArrayList(DupFile), b: std.ArrayList(DupFile)) bool {
            return std.mem.lessThan(u8, a[0].path, b[0].path);
        }
    });

    // Related files: same normalized name, any size/version. Display only.
    var by_related = std.StringHashMap(std.ArrayList([]u8)).init(allocator);
    defer by_related.deinit();

    var by_size_iter2 = by_size.iterator();
    while (by_size_iter2.next()) |size_entry| {
        for (size_entry.value_ptr.*.items) |p| {
            const fname = std.fs.path.basename(p);
            if (fname.len == 0) continue;
            const key = normalizeRelatedKey(allocator, fname) catch continue;
            defer allocator.free(key);
            if (key.len < 3) continue;

            var list = by_related.getOrCreate(key) catch continue;
            if (!list) {
                list = std.ArrayList([]u8).init(allocator);
                by_related.put(try allocator.dupe(u8, key), list.*) catch continue;
            }
            list.append(p) catch {};
        }
    }

    const RelatedGroup = struct {
        key: []u8,
        files: std.ArrayList(DupFile),
    };
    var related = std.ArrayList(RelatedGroup).init(allocator);
    defer related.deinit();

    var keys = std.ArrayList([]u8).init(allocator);
    defer keys.deinit();
    var by_related_iter = by_related.iterator();
    while (by_related_iter.next()) |e| {
        if (e.value_ptr.*.items.len >= 2 and e.value_ptr.*.items.len <= 20) {
            keys.append(try allocator.dupe(u8, e.key)) catch {};
        }
    }
    std.sort.sort([]const u8, keys.items, .{});

    const kMaxRelatedGroups = 200;
    const kMaxFilesPerRelated = 20;

    for (keys.items) |k| {
        if (related.items.len >= kMaxRelatedGroups) break;
        const paths = (by_related.get(k) orelse continue).items;
        std.sort.sort([]const u8, paths, .{});

        var g = RelatedGroup{
            .key = try allocator.dupe(u8, k),
            .files = std.ArrayList(DupFile).init(allocator),
        };
        defer g.files.deinit();

        const want = @min(paths.len, kMaxFilesPerRelated);
        for (paths[0..want]) |p| {
            const f = DupFile{
                .path = try allocator.dupe(u8, p),
                .size = fileSizeOrZero(p),
                .mtime = fileMtimeUnix(p),
            };
            g.files.append(f) catch {};
        }
        related.append(g) catch {};
    }

    // Build JSON
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    try buf.appendSlice("{\"version\":2,\"duplicate_groups\":[");
    for (duplicate_groups.items, 0..) |group, g| {
        if (g > 0) try buf.appendSlice(",");
        try buf.appendSlice("[");
        for (group.items, 0..) |f, i| {
            if (i > 0) try buf.appendSlice(",");
            const path_escaped = core.json_util.jsonEscape(allocator, f.path) catch continue;
            defer allocator.free(path_escaped);
            try std.fmt.bufPrintZ(&buf,
                "{\"path\":\"{s}\",\"size\":{},\"mtime\":{}}",
                .{path_escaped, f.size, f.mtime});
        }
        try buf.appendSlice("]");
    }
    try buf.appendSlice("],\"related_groups\":[");
    for (related.items, 0..) |group, g| {
        if (g > 0) try buf.appendSlice(",");
        const key_escaped = core.json_util.jsonEscape(allocator, group.key) catch continue;
        defer allocator.free(key_escaped);
        try std.fmt.bufPrintZ(&buf, "{\"key\":\"{s}\",\"files\":[", .{key_escaped});
        for (group.files.items, 0..) |f, i| {
            if (i > 0) try buf.appendSlice(",");
            const path_escaped = core.json_util.jsonEscape(allocator, f.path) catch continue;
            defer allocator.free(path_escaped);
            try std.fmt.bufPrintZ(&buf,
                "{\"path\":\"{s}\",\"size\":{},\"mtime\":{}}",
                .{path_escaped, f.size, f.mtime});
        }
        try buf.appendSlice("]}");
    }
    try buf.appendSlice("]}");

    return buf.toOwnedSlice();
}

/// Find duplicates and write to file
pub export fn wayer_find_duplicates_to_file(root: [*c]const u8, out_path: [*c]const u8) [*c]const u8 {
    const allocator = std.heap.page_allocator;
    const json = findDuplicates(allocator, std.mem.span(root)) catch return errorToCStr(allocator, "search_failed");
    defer allocator.free(json);

    core.text.writeTextFile(allocator, std.mem.span(out_path), json) catch return errorToCStr(allocator, "write_failed");

    const escaped = core.json_util.jsonEscape(allocator, std.mem.span(out_path)) catch return errorToCStr(allocator, "escape_failed");
    defer allocator.free(escaped);
    const msg = try std.fmt.allocPrint(allocator, "{\"status\":\"ok\",\"path\":\"{s}\"}", .{escaped}) catch return errorToCStr(allocator, "fmt_failed");
    return std.mem.toNullTerminated(allocator, msg) catch "";
}

fn errorToCStr(allocator: std.mem.Allocator, reason: []const u8) [*c]const u8 {
    const err = try std.fmt.allocPrint(allocator, "{{\"status\":\"error\",\"reason\":\"{s}\"}}", .{reason}) catch return "";
    return std.mem.toNullTerminated(allocator, err) catch "";
}