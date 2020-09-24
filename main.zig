const std = @import("std");
const Pyramid = @import("Pyramid.zig");
const Tile = @import("Tile.zig");

pub const io_mode = .evented;

pub fn main() !void {
    const chan = [_]u8{8} ** 64;
    var channels = [_][]const u8{chan[0..]} ** 3;

    var t = Tile{
        .allocator = std.heap.page_allocator,
        .index = 1,
        .x = 0,
        .y = 0,
        .h = 8,
        .w = 8,
        .channels = &channels,
    };

    var dt = try t.downscale();
    defer t.allocator.free(dt.channels);

    for (t.channels) |c| {
        printChan(c, t.w);
    }
    for (dt.channels) |c| {
        printChan(c, dt.w);
    }
}

fn printChan(chan: []const u8, w: u32) void {
    for (chan) |byte, i| {
        if (i > 0 and i % w == 0) {
            std.debug.print("\n", .{});
        }
        std.debug.print("{:2} ", .{byte});
    }
    std.debug.print("\n", .{});
    std.debug.print("\n", .{});
}
