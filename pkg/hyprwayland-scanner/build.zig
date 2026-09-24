const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

pub fn build(b: *std.Build) void {
    const upstream = b.dependency("upstream", .{});
    const pugixml = b.dependency("pugixml", .{ .target = b.graph.host, .optimize = .ReleaseFast });

    const mod = b.createModule(.{ .target = b.graph.host, .optimize = .ReleaseFast, .link_libcpp = true });
    mod.addCMacro("SCANNER_VERSION", b.fmt("\"{s}\"", .{version}));
    mod.linkLibrary(pugixml.artifact("pugixml"));
    mod.addCSourceFiles(.{
        .root = upstream.path("src"),
        .files = &.{"main.cpp"},
        .flags = &.{
            "-Wno-narrowing",
            "-Wno-unused-parameter",
            "-std=c++23",
        },
    });
    b.installArtifact(b.addExecutable(.{ .name = "hyprwayland-scanner", .root_module = mod }));
}
