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

pub fn newPyramid(args: PyramidArgs) !*Pyramid {}

pub fn pyramidLevels(args: *PyramidArgs) u64 {
    // avoid divison by zero and minus sign
    if (args.slideHeight == 0 or args.slideWidth == 0 or args.tileSize == 0) return 0;

    // number of levels n: 2^(n-1) < max(width, height) / 512 <= 2^n
    const nextPow2 = nextPowerOfTwo(1 + (math.max(args.slideWidth, args.slideHeight) - 1) / args.tileSize);
    if (nextPow2 == 0) return 0;

    return math.log2(nextPow2);
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
