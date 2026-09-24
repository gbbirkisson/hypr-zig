const std = @import("std");
const util = @import("build_util");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});
    const absl = b.dependency("abseil", .{ .target = target, .optimize = optimize }).artifact("absl");

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true });
    mod.addIncludePath(upstream.path(""));
    mod.linkLibrary(absl);
    mod.addCSourceFiles(.{ .root = upstream.path(""), .files = try util.glob(b, upstream.path(""), .{
        .include = &.{
            "re2/**/*.cc",
            "util/**/*.cc",
        },
        .exclude = &.{
            "re2/fuzzing/**",
            "re2/testing/**",
            "util/pcre.cc",
        },
    }), .flags = &.{"-std=c++23"} });
    const lib = b.addLibrary(.{ .name = "re2", .root_module = mod, .linkage = .static });
    for ([_][]const u8{
        "filtered_re2.h",
        "re2.h",
        "set.h",
        "stringpiece.h",
    }) |h|
        lib.installHeader(upstream.path(b.fmt("re2/{s}", .{h})), b.fmt("re2/{s}", .{h}));
    lib.installLibraryHeaders(absl);
    b.installArtifact(lib);
}
