const std = @import("std");
const pkgs = @import("deps.zig").pkgs;
const base_dirs = @import("deps.zig").base_dirs;
const IguaN5Builder = @import("IguaN5Builder");

pub fn build(b: *std.build.Builder) !void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    var n5_builder = try IguaN5Builder.init(b, base_dirs.iguan5);
    defer n5_builder.deinit();

    // const lib = b.addStaticLibrary("giz", "src/main.zig");
    const lib = b.addExecutable("giz", "src/main.zig");
    lib.setBuildMode(mode);
    n5_builder.link(lib);
    pkgs.addAllTo(lib);
    lib.install();

    var main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);
    n5_builder.link(main_tests);
    pkgs.addAllTo(main_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
