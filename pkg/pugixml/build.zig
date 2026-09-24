const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true });
    mod.addCSourceFiles(.{ .root = upstream.path("src"), .files = &.{"pugixml.cpp"}, .flags = &.{"-std=c++17"} });
    const lib = b.addLibrary(.{ .name = "pugixml", .root_module = mod, .linkage = .static });
    lib.installHeader(upstream.path("src/pugixml.hpp"), "pugixml.hpp");
    lib.installHeader(upstream.path("src/pugiconfig.hpp"), "pugiconfig.hpp");
    b.installArtifact(lib);
}
