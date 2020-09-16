const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

const Level = @import("Level.zig");

const Pyramid = @This();

allocator: *Allocator,
levels: []*Level
