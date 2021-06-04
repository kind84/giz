const std = @import("std");
const heap = std.heap;
const Allocator = std.mem.Allocator;
const Pyramid = @import("Pyramid.zig");
const PyramidArgs = @import("Pyramid.zig").PyramidArgs;
const Tile = @import("tile.zig").Tile;

pub const io_mode = .evented;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = &gpa.allocator;
    const chan = [_]u8{8} ** 64;
    var channels = [_][]const u8{chan[0..]} ** 3;

    var t = Tile{
        .allocator = allocator,
        .index = 1,
        .x = 0,
        .y = 0,
        .h = 8,
        .w = 8,
        .channels = &channels,
    };

    var dt = try t.downscale();
    // defer t.allocator.free(dt.channels);

    for (t.channels) |c| {
        printChan(c, t.w);
    }
    for (dt.channels) |c| {
        printChan(c, dt.w);
    }

    var pyr = try Pyramid.init(PyramidArgs{
        .allocator = allocator,
        .slideHeight = 1080,
        .slideWidth = 1920,
        .tileSize = 512,
        .chansNo = 3,
    });

    try pyr.build("../iguan5/testdata/lynx_lz4/data.n5");
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

fn buildPyramid(allocator: *Allocator) !void {
    var args = Pyramid.PyramidArgs{
        .allocator = allocator,
        .slideHeight = 1080,
        .slideWidth = 1920,
        .tileSize = 512,
        .chansNo = 3,
    };
    var pyr = Pyramid.init(&args);
}
