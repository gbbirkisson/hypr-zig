const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true });
    mod.addIncludePath(upstream.path("include"));
    mod.addIncludePath(upstream.path("src"));
    mod.addCMacro("HYPRUTILS_VERSION", b.fmt("\"{s}\"", .{version}));
    mod.linkSystemLibrary("pixman-1", .{});
    mod.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = try util.glob(b, upstream.path(""), .{ .include = &.{"src/**/*.cpp"}, .exclude = &.{"src/eventLoop/backend/Kqueue.cpp"} }),
        .flags = &.{
            "-Wno-narrowing",
            "-Wno-pointer-arith",
            "-Wno-unused-parameter",
            "-std=c++26",
        },
    });
    const lib = b.addLibrary(.{ .name = "hyprutils", .root_module = mod, .linkage = .static });
    lib.installHeadersDirectory(upstream.path("include"), "", .{ .include_extensions = null });
    b.installArtifact(lib);
}
