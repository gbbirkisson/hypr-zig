const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});
    const hyprutils = b.dependency("hyprutils", .{ .target = target, .optimize = optimize });

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true });
    mod.addIncludePath(upstream.path("include"));
    mod.addCMacro("HYPRLANG_INTERNAL", "");
    mod.linkLibrary(hyprutils.artifact("hyprutils"));
    mod.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = try util.glob(b, upstream.path(""), .{ .include = &.{"src/**/*.cpp"} }),
        .flags = &.{
            "-Wno-unused-parameter",
            "-std=c++23",
        },
    });
    const lib = b.addLibrary(.{ .name = "hyprlang", .root_module = mod, .linkage = .static });
    lib.installHeader(upstream.path("include/hyprlang.hpp"), "hyprlang.hpp");
    b.installArtifact(lib);
}
