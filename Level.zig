const Tile = @import("Tile.zig");

const Level = @This();

height: u32,
width: u32,
tilesOnWidth: u32,
tilesOnHeight: u32,
tilesCount: u32,
tiles: []Tile,
