const Tile = @import("Tile.zig");

const Level = @This();

height: u32,
width: u32,
tiles: []*Tile,
