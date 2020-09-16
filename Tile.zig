const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

const Tile = @This();

allocator: *Allocator,
index: u32,
x: u32,
y: u32,
h: u32,
w: u32,
channels: [][]u8,

pub fn init(idx: u32, x: u32, y: u32, h: u32, w: u32, chans: [][]u8) *Tile {
    return &Tile{
        .index = idx,
        .x = x,
        .y = y,
        .h = h,
        .w = w,
        .channels = chans,
    };
}

pub fn downscale(self: Tile) !*Tile {
    for (self.channels) |c| {
        // downsample in parallel
    }

    var down: [self.channels.len][]u8 = undefined;
}

fn downsample(chan: []const u8, height: u32, width: u32) ![]u8 {
    var h_odd = false;
    var w_odd = false;

    var h = height;
    if (h % 2 != 0) {
        h_odd = true;
        h -= 1;
    }
    var w = width;
    if (w % 2 != 0) {
        w_odd = true;
        w -= 1;
    }

    var size = (chan.len) >> 2;
    if (h_odd) size += ((width + 1) >> 1);

    const allocator = std.heap.page_allocator;
    var buff_down = try allocator.alloc(u8, size);
    // defer allocator.free(buff_down);
    // var buff_down: [size]u8 = undefined;

    var idx: u64 = 0;
    var i: u32 = 0;

    while (i < h) : (i += 2) {
        const r1 = chan[i * width .. (i * width) + width];
        const r2 = chan[(i + 1) * width .. ((i + 1) * width) + width];

        var j: u32 = 0;

        while (j < w) : (j += 2) {
            buff_down[idx] = (r1[j] >> 2) + (r1[j + 1] >> 2) + (r2[j] >> 2) + (r2[j + 1] >> 2);
            idx += 1;
        }

        if (w_odd) {
            buff_down[idx] = (r1[w] >> 1) + (r2[w] >> 1);
            idx += 1;
        }
    }

    if (h_odd) {
        const r = chan[i * width .. (i * width) + width];
        var j: u32 = 0;

        while (j < w) : (j += 2) {
            buff_down[idx] = (r[j] >> 1) + (r[j + 1] >> 1);
            idx += 1;
        }

        if (w_odd) {
            buff_down[idx] = chan[chan.len - 1];
            idx += 1;
        }
    }

    return buff_down;
}

test "downsample" {
    const tests = [_]struct {
        chan: []const u8,
        exp_len: u32,
        height: u32,
        width: u32,
    }{
        .{
            .chan = &[_]u8{8} ** 64,
            .exp_len = 16,
            .height = 8,
            .width = 8,
        },
        .{
            .chan = &[_]u8{8} ** 81,
            .exp_len = 25,
            .height = 9,
            .width = 9,
        },
    };

    const allocator = std.heap.page_allocator;

    for (tests) |t| {
        const d = try downsample(t.chan, t.height, t.width);
        defer allocator.free(d);

        std.debug.assert(d.len == t.exp_len);
        for (d) |byte| {
            std.debug.assert(byte == t.chan[0]);
        }
    }
}
