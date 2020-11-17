const std = @import("std");
const mem = std.mem;
const math = std.math;
const Allocator = mem.Allocator;

const tile = @import("tile.zig");

const Level = struct {
    height: u32,
    width: u32,
    tilesOnWidth: u32,
    tilesOnHeight: u32,
    tilesCount: u32,
    tiles: []tile.Tile,
};

const Pyramid = @This();

allocator: *Allocator,
levels: []Level,
chansNo: u8,

pub const PyramidArgs = struct {
    allocator: *Allocator,
    slideHeight: u32,
    slideWidth: u32,
    tileSize: u32,
    chansNo: u8,
};

pub fn init(args: *PyramidArgs) !Pyramid {
    if (args.slideHeight == 0 or args.slideWidth == 0 or args.tileSize == 0) {
        return error.InvalidArgument;
    }

    const num_levels = pyramidLevels(args);

    var levels = try args.allocator.alloc(Level, num_levels + 1);

    var tot_tiles: u32 = 0;
    var l: u5 = 0;

    while (l <= num_levels) : (l += 1) {
        const h = 1 + ((args.slideHeight - 1) >> l);
        const w = 1 + ((args.slideWidth - 1) >> l);

        // number of tiles per dimension
        const tiles_w = 1 + ((w - 1) / args.tileSize);
        const tiles_h = 1 + ((h - 1) / args.tileSize);

        var level = Level{
            .height = h,
            .width = w,
            .tilesOnWidth = tiles_w,
            .tilesOnHeight = tiles_h,
            .tilesCount = tiles_h * tiles_w,
            .tiles = undefined,
        };
        tot_tiles += level.tilesCount;

        var tiles = try args.allocator.alloc(tile.Tile, level.tilesCount);

        var i: u32 = 0;
        while (i < tiles_h) : (i += 1) {
            var j: u32 = 0;
            while (j < tiles_w) : (j += 1) {
                var index = j + (tiles_w * i);

                // compute tile dimensions
                var tw = tileSide(args.tileSize, w, tiles_w, j);
                var th = tileSide(args.tileSize, h, tiles_h, i);

                var t = tile.Tile{
                    .allocator = args.allocator,
                    .index = index,
                    .x = j * args.tileSize,
                    .y = i * args.tileSize,
                    .h = th,
                    .w = tw,
                    .channels = undefined,
                };

                tiles[index] = t;
            }
        }

        level.tiles = tiles;
        levels[l] = level;
    }

    return Pyramid{
        .allocator = args.allocator,
        .levels = levels,
        .chansNo = args.chansNo,
    };
}

test "init" {
    var tile1 = tile.Tile{ .allocator = undefined, .index = 0, .x = 0, .y = 0, .h = 512, .w = 512, .channels = undefined };
    var tile2 = tile.Tile{ .allocator = undefined, .index = 1, .x = 512, .y = 0, .h = 512, .w = 512, .channels = undefined };
    var tile3 = tile.Tile{ .allocator = undefined, .index = 2, .x = 512 * 2, .y = 0, .h = 512, .w = 512, .channels = undefined };
    var tile4 = tile.Tile{ .allocator = undefined, .index = 3, .x = 512 * 3, .y = 0, .h = 512, .w = 384, .channels = undefined };
    var tile5 = tile.Tile{ .allocator = undefined, .index = 4, .x = 0, .y = 512, .h = 512, .w = 512, .channels = undefined };
    var tile6 = tile.Tile{ .allocator = undefined, .index = 5, .x = 512, .y = 512, .h = 512, .w = 512, .channels = undefined };
    var tile7 = tile.Tile{ .allocator = undefined, .index = 6, .x = 512 * 2, .y = 512, .h = 512, .w = 512, .channels = undefined };
    var tile8 = tile.Tile{ .allocator = undefined, .index = 7, .x = 512 * 3, .y = 512, .h = 512, .w = 384, .channels = undefined };
    var tile9 = tile.Tile{ .allocator = undefined, .index = 8, .x = 0, .y = 1024, .h = 56, .w = 512, .channels = undefined };
    var tile10 = tile.Tile{ .allocator = undefined, .index = 9, .x = 512, .y = 1024, .h = 56, .w = 512, .channels = undefined };
    var tile11 = tile.Tile{ .allocator = undefined, .index = 10, .x = 512 * 2, .y = 1024, .h = 56, .w = 512, .channels = undefined };
    var tile12 = tile.Tile{ .allocator = undefined, .index = 11, .x = 512 * 3, .y = 1024, .h = 56, .w = 384, .channels = undefined };

    var tiles1 = &[_]tile.Tile{
        tile1,
        tile2,
        tile3,
        tile4,
        tile5,
        tile6,
        tile7,
        tile8,
        tile9,
        tile10,
        tile11,
        tile12,
    };

    var tile13 = tile.Tile{ .allocator = undefined, .index = 0, .x = 0, .y = 0, .h = 512, .w = 512, .channels = undefined };
    var tile14 = tile.Tile{ .allocator = undefined, .index = 1, .x = 512, .y = 0, .h = 512, .w = 448, .channels = undefined };
    var tile15 = tile.Tile{ .allocator = undefined, .index = 2, .x = 0, .y = 512, .h = 28, .w = 512, .channels = undefined };
    var tile16 = tile.Tile{ .allocator = undefined, .index = 3, .x = 512, .y = 512, .h = 28, .w = 448, .channels = undefined };

    var tiles2 = &[_]tile.Tile{
        tile13,
        tile14,
        tile15,
        tile16,
    };

    var tile17 = tile.Tile{ .allocator = undefined, .index = 0, .x = 0, .y = 0, .h = 270, .w = 480, .channels = undefined };

    var tiles3 = &[_]tile.Tile{tile17};

    var levels = &[_]Level{
        Level{
            .height = 1080,
            .width = 1920,
            .tilesOnWidth = 4,
            .tilesOnHeight = 3,
            .tilesCount = 12,
            .tiles = tiles1,
        },
        Level{
            .height = 540,
            .width = 960,
            .tilesOnWidth = 2,
            .tilesOnHeight = 2,
            .tilesCount = 4,
            .tiles = tiles2,
        },
        Level{
            .height = 270,
            .width = 480,
            .tilesOnWidth = 1,
            .tilesOnHeight = 1,
            .tilesCount = 1,
            .tiles = tiles3,
        },
    };

    const tests = [_]struct {
        tileSize: u32,
        h: u32,
        w: u32,
        expected: Pyramid,
        expectsErr: bool,
    }{
        .{
            .tileSize = 512,
            .h = 1080,
            .w = 1920,
            .expected = Pyramid{
                .allocator = undefined,
                .levels = levels,
                .chansNo = 3,
            },
            .expectsErr = false,
        },
    };

    for (tests) |t| {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = &gpa.allocator;
        const arena = &std.heap.ArenaAllocator.init(allocator);
        const a = &arena.allocator;
        defer arena.deinit();

        var args = PyramidArgs{
            .allocator = a,
            .slideHeight = t.h,
            .slideWidth = t.w,
            .tileSize = t.tileSize,
            .chansNo = 3,
        };

        const p = try init(&args);

        defer a.destroy(&p);

        std.testing.expectEqual(t.expected.levels.len, p.levels.len);
        std.testing.expectEqual(@as(u8, 3), p.chansNo);

        for (p.levels) |*level, i| {
            std.testing.expectEqual(t.expected.levels[i].tiles.len, level.tiles.len);
            std.testing.expectEqual(t.expected.levels[i].tilesCount, level.tilesCount);
            std.testing.expectEqual(t.expected.levels[i].height, level.height);
            std.testing.expectEqual(t.expected.levels[i].width, level.width);
            std.testing.expectEqual(t.expected.levels[i].tilesOnWidth, level.tilesOnWidth);
            std.testing.expectEqual(t.expected.levels[i].tilesOnHeight, level.tilesOnHeight);

            for (level.tiles) |l_tile, j| {
                std.testing.expectEqual(t.expected.levels[i].tiles[j].x, l_tile.x);
                std.testing.expectEqual(t.expected.levels[i].tiles[j].y, l_tile.y);
                std.testing.expectEqual(t.expected.levels[i].tiles[j].h, l_tile.h);
                std.testing.expectEqual(t.expected.levels[i].tiles[j].w, l_tile.w);
            }
        }
    }
}

/// Computes the number of levels in the pyramid based on the provided starting
/// dimensions.
pub fn pyramidLevels(args: *const PyramidArgs) u64 {
    // avoid divison by zero and minus sign
    if (args.slideHeight == 0 or args.slideWidth == 0 or args.tileSize == 0) return 0;

    // number of levels n: 2^(n-1) < max(width, height) / 512 <= 2^n
    const next_pow_2 = nextPowerOfTwo(1 + (math.max(args.slideWidth, args.slideHeight) - 1) / args.tileSize);
    if (next_pow_2 == 0) return 0;

    return math.log2(next_pow_2);
}

test "pyramidLevels" {
    const tests = [_]struct {
        tileSize: u32,
        h: u32,
        w: u32,
        expected: u64,
    }{
        .{
            .tileSize = 512,
            .h = 512 * 3,
            .w = 512 * 3,
            .expected = 2,
        },
        .{
            .tileSize = 512,
            .h = 512,
            .w = 512,
            .expected = 0,
        },
        .{
            .tileSize = 512,
            .h = 511,
            .w = 511,
            .expected = 0,
        },
        .{
            .tileSize = 512,
            .h = (512 * 3) + 42,
            .w = (512 * 3) + 42,
            .expected = 2,
        },
        .{
            .tileSize = 512,
            .h = 512 * 4,
            .w = 512 * 4,
            .expected = 2,
        },
        .{
            .tileSize = 512,
            .h = (512 * 4) + 1,
            .w = (512 * 4) + 1,
            .expected = 3,
        },
        .{
            .tileSize = 512,
            .h = (512 * 3) + 42,
            .w = 511,
            .expected = 2,
        },
        .{
            .tileSize = 512,
            .h = 511,
            .w = (512 * 3) + 42,
            .expected = 2,
        },
        .{
            .tileSize = 512,
            .h = 512 * 3,
            .w = 512,
            .expected = 2,
        },
        .{
            .tileSize = 512,
            .h = 512,
            .w = 512 * 3,
            .expected = 2,
        },
        .{
            .tileSize = 0,
            .h = 42,
            .w = 42,
            .expected = 0,
        },
        .{
            .tileSize = 42,
            .h = 0,
            .w = 42,
            .expected = 0,
        },
        .{
            .tileSize = 42,
            .h = 42,
            .w = 0,
            .expected = 0,
        },
    };

    for (tests) |t| {
        const levels = pyramidLevels(&PyramidArgs{
            .allocator = undefined,
            .slideHeight = t.h,
            .slideWidth = t.w,
            .tileSize = t.tileSize,
            .chansNo = 3,
        });

        std.testing.expect(levels == t.expected);
    }
}

fn tileSide(tileSize: u32, sideSize: u32, tilesOnSide: u32, index: u32) u32 {
    if (index + 1 == tilesOnSide) {
        return sideSize - (tileSize * (tilesOnSide - 1));
    } else return tileSize;
}

test "tileSide" {
    const tests = [_]struct {
        tileSize: u32,
        sideSize: u32,
        tilesOnSide: u32,
        index: u32,
        expected: u32,
    }{
        .{
            .tileSize = 512,
            .sideSize = 1920,
            .tilesOnSide = 4,
            .index = 3,
            .expected = 384,
        },
        .{
            .tileSize = 512,
            .sideSize = 1920,
            .tilesOnSide = 4,
            .index = 2,
            .expected = 512,
        },
        .{
            .tileSize = 512,
            .sideSize = 1080,
            .tilesOnSide = 3,
            .index = 2,
            .expected = 56,
        },
    };

    for (tests) |t| {
        const s = tileSide(t.tileSize, t.sideSize, t.tilesOnSide, t.index);

        std.testing.expect(s == t.expected);
    }
}

/// Returns `v` if it is a power-of-two, or else the next-highest power-of-two.
fn nextPowerOfTwo(val: u64) u64 {
    if (val == math.maxInt(u64) or val == 0) return 0;
    var v = val;
    v -= 1;
    v |= v >> 1;
    v |= v >> 2;
    v |= v >> 4;
    v |= v >> 8;
    v |= v >> 16;
    v |= v >> 32;
    v += 1;
    return v;
}

test "nextPowerOfTwo" {
    const tests = [_]struct {
        val: u64,
        expect: u64,
    }{
        .{
            .val = 512,
            .expect = 512,
        },
        .{
            .val = 513,
            .expect = 1024,
        },
        .{
            .val = 511,
            .expect = 512,
        },
        .{
            .val = math.maxInt(u64),
            .expect = 0,
        },
        .{
            .val = 2,
            .expect = 2,
        },
        .{
            .val = 1,
            .expect = 1,
        },
        .{
            .val = 0,
            .expect = 0,
        },
    };

    for (tests) |t| {
        const p2 = nextPowerOfTwo(t.val);
        std.testing.expect(p2 == t.expect);
    }
}
