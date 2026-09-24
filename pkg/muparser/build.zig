const std = @import("std");
const util = @import("build_util");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true });
    mod.addIncludePath(upstream.path("include"));
    mod.addCMacro("MUPARSER_STATIC", "");
    mod.addCMacro("MUPARSER_DLL", "");
    mod.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = try util.glob(b, upstream.path(""), .{ .include = &.{"src/*.cpp"} }),
        .flags = &.{"-std=c++20"},
    });
    const lib = b.addLibrary(.{ .name = "muparser", .root_module = mod, .linkage = .static });
    lib.installHeadersDirectory(upstream.path("include"), "", .{});
    b.installArtifact(lib);
}
