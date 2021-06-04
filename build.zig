const std = @import("std");
const pkgs = @import("deps.zig").pkgs;

fn addDeps(step: *std.build.LibExeObjStep) void {
    step.addIncludeDir("./.gyro/iguan5-kind84-4a62a7dc9435ce60f379581798f98d6fc694b47a/pkg/src/vendor/");
    step.addCSourceFile("./.gyro/iguan5-kind84-4a62a7dc9435ce60f379581798f98d6fc694b47a/pkg/src/vendor/lz4.c", &.{});
}

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    // const lib = b.addStaticLibrary("giz", "src/main.zig");
    const lib = b.addExecutable("giz", "src/main.zig");
    pkgs.addAllTo(lib);
    lib.setBuildMode(mode);
    lib.linkLibC();
    addDeps(lib);
    lib.install();

    var main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
