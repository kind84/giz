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
        const FrameType = @TypeOf(async downsample(self.allocator, self.channels[0], self.h, self.w, false));
        var frames = try self.allocator.alloc(FrameType, self.channels.len);
        defer self.allocator.free(frames);
        var down = try self.allocator.alloc([]u8, self.channels.len);

        for (self.channels) |c, i| {
            frames[i] = async downsample(self.allocator, c, self.h, self.w, false);
        }
        for (frames) |*f, i| {
            down[i] = try await f;
        }

        return &Tile{
            .allocator = self.allocator,
            .index = self.index,
            .x = self.x,
            .y = self.y,
            .h = self.h >> 1,
            .w = self.w >> 1,
            .channels = down,
        };
    }

    test "downscale" {
        const chan = [_]u8{8} ** 64;
        var channels = [_][]const u8{chan[0..]} ** 3;
        const allocator = std.heap.page_allocator;

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

        try std.testing.expect(dt.channels.len == 3);
        try std.testing.expect(dt.channels[0].len == 16);
        try std.testing.expect(dt.channels[0][0] == 8);
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

        try std.testing.expectEqual(t.merge.len, m.len);
        for (m) |m_chan, i| {
            try std.testing.expectEqualSlices(u8, t.merge[i], m_chan);
        }
    }
}

/// downsamples a channel by taking the average of 2x2
/// pixel squares.
fn downsample(allocator: *Allocator, chan: []const u8, pixelsH: u32, pixelsW: u32, XVIbits: bool) ![]u8 {
    const step: u32 = if (XVIbits) 2 else 1;
    var sides = Sides{ .oddness = OddSide.None };

    var ph = pixelsH;
    if (ph % 2 != 0) {
        sides.heightOdd();
        ph -= 1;
    }
    var pw = pixelsW;
    if (pw % 2 != 0) {
        sides.widthOdd();
        pw -= 1;
    }

    // compute the exact size of the buffer holding the downsampled channel
    var size = (ph * pw) >> 2;

    // for each odd side, add the size for the downsampled opposite side
    switch (sides.oddness) {
        OddSide.Height => size += (pw >> 1),
        OddSide.Width => size += (ph >> 1),
        OddSide.Both => size += (pw >> 1) + (ph >> 1) + 1,
        OddSide.None => {},
    }
    size *= step;

    var buff_down = try allocator.alloc(u8, size);
    // defer allocator.free(buff_down);
    // var buff_down: [size]u8 = undefined;

    var width = pixelsW * step;
    var h = ph;
    var w = pw * step;
    var idx: u64 = 0;
    var i: u32 = 0;

    while (i < h) : (i += 2) {
        const r1 = chan[i * width .. (i * width) + width];
        const r2 = chan[(i + 1) * width .. ((i + 1) * width) + width];

        var j: u32 = 0;

        while (j < w) : (j += (step * 2)) {
            buff_down[idx] = @intCast(u8, (@intCast(u16, r1[j]) +
                @intCast(u16, r1[j + step]) +
                @intCast(u16, r2[j]) +
                @intCast(u16, r2[j + step])) >> 2);
            idx += 1;

            if (XVIbits) {
                var k = j + 1;
                buff_down[idx] = @intCast(u8, (@intCast(u16, r1[k]) +
                    @intCast(u16, r1[k + step]) +
                    @intCast(u16, r2[k]) +
                    @intCast(u16, r2[k + step])) >> 2);
                idx += 1;
            }
        }

        if (sides.hasWidthOdd()) {
            buff_down[idx] = @intCast(u8, (@intCast(u16, r1[w]) + @intCast(u16, r2[w])) >> 1);
            idx += 1;

            if (XVIbits) {
                buff_down[idx] = @intCast(u8, (@intCast(u16, r1[w + 1]) + @intCast(u16, r2[w + 1])) >> 1);
                idx += 1;
            }
        }
    }

    if (sides.hasHeightOdd()) {
        // seek to the last row
        const r = chan[i * width .. (i * width) + width];
        var j: u32 = 0;

        while (j < w) : (j += (step * 2)) {
            buff_down[idx] = @intCast(u8, (@intCast(u16, r[j]) + @intCast(u16, r[j + step])) >> 1);
            idx += 1;

            if (XVIbits) {
                var k = j + 1;
                buff_down[idx] = @intCast(u8, (@intCast(u16, r[k]) + @intCast(u16, r[k + step])) >> 1);
                idx += 1;
            }
        }

        if (sides.hasWidthOdd()) {
            buff_down[idx] = chan[chan.len - step];
            idx += 1;

            if (XVIbits) {
                buff_down[idx] = chan[chan.len - 1];
                idx += 1;
            }
        }
    }

    return buff_down;
}

test "downsample" {
    const tests = [_]struct {
        chan: []const u8,
        exp: []const u8,
        height: u32,
        width: u32,
        XVIbits: bool,
    }{
        // even sides 8bits square
        .{
            .chan = &[_]u8{255} ** 64,
            .exp = &[_]u8{255} ** 16,
            .height = 8,
            .width = 8,
            .XVIbits = false,
        },
        // even sides 16bits square
        .{
            .chan = &[_]u8{ 255, 254 } ** 64,
            .exp = &[_]u8{ 255, 254 } ** 16,
            .height = 8,
            .width = 8,
            .XVIbits = true,
        },
        // odd sides 8bits square
        .{
            .chan = &[_]u8{255} ** 81,
            .exp = &[_]u8{255} ** 25,
            .height = 9,
            .width = 9,
            .XVIbits = false,
        },
        // spare row 8bits
        .{
            .chan = &[_]u8{255} ** 72,
            .exp = &[_]u8{255} ** 20,
            .height = 9,
            .width = 8,
            .XVIbits = false,
        },
        // spare row 16bits
        .{
            .chan = &[_]u8{ 255, 254 } ** 72,
            .exp = &[_]u8{ 255, 254 } ** 20,
            .height = 9,
            .width = 8,
            .XVIbits = true,
        },
        // spare row & column 8bits
        .{
            .chan = &[_]u8{255} ** 63,
            .exp = &[_]u8{255} ** 20,
            .height = 7,
            .width = 9,
            .XVIbits = false,
        },
        // spare column 8bits
        .{
            .chan = &[_]u8{255} ** 54,
            .exp = &[_]u8{255} ** 15,
            .height = 6,
            .width = 9,
            .XVIbits = false,
        },
        // spare column small 8bits
        .{
            .chan = &[_]u8{255} ** 6,
            .exp = &[_]u8{255} ** 2,
            .height = 2,
            .width = 3,
            .XVIbits = false,
        },
        // spare row small 8bits
        .{
            .chan = &[_]u8{255} ** 6,
            .exp = &[_]u8{255} ** 2,
            .height = 3,
            .width = 2,
            .XVIbits = false,
        },
        // single column 8bits
        .{
            .chan = &[_]u8{255} ** 2,
            .exp = &[_]u8{255},
            .height = 2,
            .width = 1,
            .XVIbits = false,
        },
        // single column 16bits
        .{
            .chan = &[_]u8{ 255, 254 } ** 2,
            .exp = &[_]u8{ 255, 254 },
            .height = 2,
            .width = 1,
            .XVIbits = true,
        },
        // single row 8bits
        .{
            .chan = &[_]u8{255} ** 2,
            .exp = &[_]u8{255},
            .height = 1,
            .width = 2,
            .XVIbits = false,
        },
    };

    const allocator = std.heap.page_allocator;

    for (tests) |t| {
        const d = try downsample(allocator, t.chan, t.height, t.width, t.XVIbits);
        defer allocator.free(d);

        std.debug.assert(d.len == t.exp.len);
        for (d) |byte, i| {
            try std.testing.expect(byte == t.exp[i]);
        }
    }
}
