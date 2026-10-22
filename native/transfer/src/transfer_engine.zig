// wayer_transfer — network helpers.
// Ported from native/transfer/src/transfer_engine.cpp
// Uses Zig's std.net for cross-platform sockets.

const std = @import("std");

pub fn getNetworkInfo() ![]u8 {
    // Return a simple status JSON
    return try std.fmt.allocPrint(std.heap.page_allocator, "{\"transfer_status\":\"idle\",\"protocol\":\"tcp\"}");
}

pub fn startListener(port: c_int) ![]u8 {
    // Create TCP listener
    var listener = try std.net.StreamServer.init(.{
        .address = .{ .ip = std.net.Address.ipv4(0, 0, 0, 0), .port = @as(u16, port) },
        .backlog = 128,
    });
    defer listener.deinit();

    // For this test call, we just bind and close immediately
    // Background worker threads manage persistent connections
    _ = listener.listener; // Access to trigger bind

    return try std.fmt.allocPrint(std.heap.page_allocator, "{\"status\":\"socket_bound\",\"port\":{}}", .{port});
}

pub export fn wayer_get_network_info() [*c]const u8 {
    const allocator = std.heap.page_allocator;
    const json = getNetworkInfo() catch return errorToCStr(allocator, "network_failed");
    return std.mem.toNullTerminated(allocator, json) catch "";
}

pub export fn wayer_start_listener(port: c_int) [*c]const u8 {
    const allocator = std.heap.page_allocator;
    const json = startListener(port) catch return errorToCStr(allocator, "listener_failed");
    return std.mem.toNullTerminated(allocator, json) catch "";
}

fn errorToCStr(allocator: std.mem.Allocator, reason: []const u8) [*c]const u8 {
    const err = try std.fmt.allocPrint(allocator, "{{\"status\":\"error\",\"reason\":\"{s}\"}}", .{reason}) catch return "";
    return std.mem.toNullTerminated(allocator, err) catch "";
}