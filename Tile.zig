const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

pub const io_mode = .evented;

const OddSide = enum(u3) {
    None = 1,
    Height = 2,
    Width = 3,
    Both = 6,
};

const Sides = struct {
    oddness: OddSide,

    fn hasHeightOdd(self: *Sides) bool {
        return @enumToInt(self.oddness) % 2 == 0;
    }

    fn hasWidthOdd(self: *Sides) bool {
        return @enumToInt(self.oddness) % 3 == 0;
    }

    fn hasBothSidesOdd(self: *Sides) bool {
        return self.oddness == OddSize.Both;
    }

    fn heightOdd(self: *Sides) void {
        if (!self.hasHeightOdd()) {
            self.oddness = @intToEnum(OddSide, @enumToInt(self.oddness) * @enumToInt(OddSide.Height));
        }
    }

    fn widthOdd(self: *Sides) void {
        if (!self.hasWidthOdd()) {
            self.oddness = @intToEnum(OddSide, @enumToInt(self.oddness) * @enumToInt(OddSide.Width));
        }
    }
};

pub const Tile = struct {
    allocator: *Allocator,
    index: u32,
    x: u32,
    y: u32,
    h: u32,
    w: u32,
    channels: [][]const u8,

    pub fn downscale(self: Tile) !*Tile {
        const FrameType = @TypeOf(async downsample(self.channels[0], self.h, self.w));
        var frames = try self.allocator.alloc(FrameType, self.channels.len);
        defer self.allocator.free(frames);
        var down = try self.allocator.alloc([]u8, self.channels.len);

        for (self.channels) |c, i| {
            frames[i] = async downsample(c, self.h, self.w);
        }
        for (frames) |*f, i| {
            down[i] = try await f;
        }

        return &Tile{
            .allocator = self.allocator,
            .index = self.index,
            .x = self.x,
            .y = self.y,
            .h = 1 + (self.h - 1) >> 1,
            .w = 1 + (self.w - 1) >> 1,
            .channels = down,
        };
    }

    test "downscale" {
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

        std.testing.expect(dt.channels.len == 3);
        std.testing.expect(dt.channels[0].len == 16);
        std.testing.expect(dt.channels[0][0] == 8);
    }
};

/// merges two horizontaly adiacent tiles and returns the result.
pub fn mergeTiles(t: *Tile, next: *Tile) ![][]u8 {
    const merged_size = (t.h * t.w) + (next.h * next.w);
    var out = try t.allocator.alloc([]u8, t.channels.len);
    for (out) |*c_out| {
        c_out.* = try t.allocator.alloc(u8, merged_size);
    }

    const m_w = t.w + next.w;
    var n: u8 = 0;
    while (n < t.channels.len) : (n += 1) {
        var r: u32 = 0;
        while (r < t.h) : (r += 1) {
            mem.copy(u8, out[n][r * m_w .. r * m_w + t.w], t.channels[n][r * t.w .. r * t.w + t.w]);
            mem.copy(u8, out[n][r * m_w + t.w .. r * m_w + t.w + next.w], next.channels[n][r * t.w .. r * t.w + t.w]);
        }
    }

    return out;
}

test "mergeTiles" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = &gpa.allocator;
    const arena = &std.heap.ArenaAllocator.init(allocator);
    const a = &arena.allocator;
    defer arena.deinit();

    var odd = [_]u8{ 1, 3 };
    var even = [_]u8{ 2, 4 };
    var all = [_]u8{ 1, 2, 3, 4 };
    var sqr1 = [_]u8{ 0, 0, 2, 2 };
    var sqr2 = [_]u8{ 1, 1, 3, 3 };
    var rect = [_]u8{ 0, 0, 1, 1, 2, 2, 3, 3 };

    var tests = [_]struct {
        tileLeft: Tile,
        tileRight: Tile,
        merge: [][]u8,
    }{
        .{
            .tileLeft = Tile{
                .allocator = a,
                .index = 0,
                .x = 0,
                .y = 0,
                .h = 2,
                .w = 1,
                .channels = &[_][]u8{&odd},
            },
            .tileRight = Tile{
                .allocator = a,
                .index = 0,
                .x = 2,
                .y = 0,
                .h = 2,
                .w = 1,
                .channels = &[_][]u8{&even},
            },
            .merge = &[_][]u8{&all},
        },
        .{
            .tileLeft = Tile{
                .allocator = a,
                .index = 0,
                .x = 0,
                .y = 0,
                .h = 2,
                .w = 2,
                .channels = &[_][]u8{&sqr1},
            },
            .tileRight = Tile{
                .allocator = a,
                .index = 0,
                .x = 2,
                .y = 0,
                .h = 2,
                .w = 2,
                .channels = &[_][]u8{&sqr2},
            },
            .merge = &[_][]u8{&rect},
        },
    };

    for (tests) |*t| {
        const m = try mergeTiles(&t.tileLeft, &t.tileRight);

        std.testing.expectEqual(t.merge.len, m.len);
        for (m) |m_chan, i| {
            std.testing.expectEqualSlices(u8, t.merge[i], m_chan);
        }
    }
}

/// downsamples a channel by taking the average of 2x2
/// pixel squares.
fn downsample(chan: []const u8, height: u32, width: u32) ![]u8 {
    var sides = Sides{ .oddness = OddSide.None };

    var h = height;
    if (h % 2 != 0) {
        sides.heightOdd();
        h -= 1;
    }
    var w = width;
    if (w % 2 != 0) {
        sides.widthOdd();
        w -= 1;
    }

    var size = (3 + chan.len) >> 2;

    switch (sides.oddness) {
        OddSide.Height => size += ((1 + width) >> 2),
        OddSide.Width => size += ((1 + height) >> 2),
        OddSide.Both => size += ((1 + width) >> 2) + ((1 + height) >> 2),
        OddSide.None => {},
    }

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

        if (sides.hasWidthOdd()) {
            buff_down[idx] = (r1[w] >> 1) + (r2[w] >> 1);
            idx += 1;
        }
    }

    if (sides.hasHeightOdd()) {
        const r = chan[i * width .. (i * width) + width];
        var j: u32 = 0;

        while (j < w) : (j += 2) {
            buff_down[idx] = (r[j] >> 1) + (r[j + 1] >> 1);
            idx += 1;
        }

        if (sides.hasWidthOdd()) {
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
        .{
            .chan = &[_]u8{8} ** 72,
            .exp_len = 20,
            .height = 9,
            .width = 8,
        },
        .{
            .chan = &[_]u8{8} ** 63,
            .exp_len = 20,
            .height = 7,
            .width = 9,
        },
        .{
            .chan = &[_]u8{8} ** 54,
            .exp_len = 15,
            .height = 9,
            .width = 6,
        },
        .{
            .chan = &[_]u8{8} ** 6,
            .exp_len = 2,
            .height = 2,
            .width = 3,
        },
        .{
            .chan = &[_]u8{8} ** 2,
            .exp_len = 1,
            .height = 2,
            .width = 1,
        },
    };

    const allocator = std.heap.page_allocator;

    for (tests) |t| {
        const d = try downsample(t.chan, t.height, t.width);
        defer allocator.free(d);

        std.debug.assert(d.len == t.exp_len);
        for (d) |byte| {
            std.testing.expect(byte == t.chan[0]);
        }
    }
}
