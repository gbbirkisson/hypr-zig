const std = @import("std");
const util = @import("build_util");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});
    const fmt = b.dependency("fmt", .{ .target = target, .optimize = optimize }).artifact("fmt");

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true });
    mod.addIncludePath(upstream.path("include"));
    for ([_][2][]const u8{
        .{ "SPDLOG_COMPILED_LIB", "1" },
        .{ "SPDLOG_FMT_EXTERNAL", "1" },
        .{ "SPDLOG_FWRITE_UNLOCKED", "1" },
    }) |m| mod.addCMacro(m[0], m[1]);
    mod.linkLibrary(fmt);
    mod.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = try util.glob(b, upstream.path(""), .{
            .include = &.{"src/*.cpp"},
            // Only for the bundled fmt copy.
            .exclude = &.{"src/bundled_fmtlib_format.cpp"},
        }),
        .flags = &.{"-std=c++20"},
    });
    const lib = b.addLibrary(.{ .name = "spdlog", .root_module = mod, .linkage = .static });
    lib.installHeadersDirectory(upstream.path("include/spdlog"), "spdlog", .{});
    lib.installLibraryHeaders(fmt);
    b.installArtifact(lib);
}
