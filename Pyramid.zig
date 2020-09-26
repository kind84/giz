const std = @import("std");
const mem = std.mem;
const math = std.math;
const Allocator = mem.Allocator;

const Level = @import("Level.zig");

const Pyramid = @This();

allocator: *Allocator,
levels: []*Level,

pub const PyramidArgs = struct {
    slideWidth: u32,
    slideHeight: u32,
    tileSize: u32,
};

pub fn init(args: *PyramidArgs) !*Pyramid {
    if (args.slideHeight == 0 or args.slideWidth == 0 or args.tileSize == 0) {
        return error.InvalidArgument;
    }

    const num_levels = pyramidLevels(args);

    var tot_tiles = 0;
    var l = 0;

    while (l < num_levels) : (l += 1) {
        const h = 1 + (args.SlideHeight - 1) >> l;
        const w = 1 + (args.SlideWidth - 1) >> l;

        // number of tiles per dimension
        const tiles_w = 1 + (w - 1) / args.TileSize;
        const tiles_h = 1 + (h - 1) / args.TileSize;

        var level = &Level{
            .height = h,
            .width = w,
            // .TilesOnWidth = tilesW,
            // .TilesOnHeight = tilesH,
            // .TilesCount = tilesH * tilesW,
            .tiles = undefined,
        };
        tot_tiles += level.TilesCount;
        // TODO: initialize level Tiles slice

        var i = 0;
        var j = 0;
        while (i < tiles_h) : (i += 1) {
            while (j < tiles_w) : (j += 1) {
                const index = j + (tiles_w * i);

                // compute tile dimensions
                const tw = tileSide(args.tileSize, w, tiles_w);
                const th = tileSide(args.tileSize, h, tiles_h);

                // const args := &NewTileArgs{
                // 	Index:  index,
                // 	X:      j * args.TileSize,
                // 	Y:      i * args.TileSize,
                // 	Height: th,
                // 	Width:  tw,
                // }
                // t := NewTile(args)

                // level.Tiles = append(level.Tiles, t)
            }
        }
    }
}

/// Computes the number of levels in the pyramid based on the provided starting
/// dimensions.
pub fn pyramidLevels(args: *PyramidArgs) u64 {
    // avoid divison by zero and minus sign
    if (args.slideHeight == 0 or args.slideWidth == 0 or args.tileSize == 0) return 0;

    // number of levels n: 2^(n-1) < max(width, height) / 512 <= 2^n
    const next_pow_2 = nextPowerOfTwo(1 + (math.max(args.slideWidth, args.slideHeight) - 1) / args.tileSize);
    if (next_pow_2 == 0) return 0;

    return math.log2(next_pow_2);
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

        std.debug.assert(s == t.expected);
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
            .slideHeight = t.h,
            .slideWidth = t.w,
            .tileSize = t.tileSize,
        });

        std.debug.assert(levels == t.expected);
    }
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
        std.debug.assert(p2 == t.expect);
    }
}
