const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});
    const sv = std.SemanticVersion.parse(version) catch unreachable;
    const sigc = b.dependency("sigcpp", .{ .target = target, .optimize = optimize }).artifact("sigc-2.0");

    const config = b.addConfigHeader(.{ .style = .{ .meson = upstream.path("cairommconfig.h.meson") }, .include_path = "cairommconfig.h" }, .{
        .CAIROMM_DISABLE_DEPRECATED = null,
        .CAIROMM_EXCEPTIONS_ENABLED = 1,
        .CAIROMM_MAJOR_VERSION = @as(i64, @intCast(sv.major)),
        .CAIROMM_MICRO_VERSION = @as(i64, @intCast(sv.patch)),
        .CAIROMM_MINOR_VERSION = @as(i64, @intCast(sv.minor)),
    });

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true });
    mod.addIncludePath(upstream.path(""));
    mod.addConfigHeader(config);
    mod.addCMacro("CAIROMM_BUILD", "1");
    mod.linkLibrary(sigc);
    mod.linkSystemLibrary("cairo", .{});
    // Platform sources are guarded by cairo-features.h, so every file compiles everywhere.
    mod.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = try util.glob(b, upstream.path(""), .{ .include = &.{"cairomm/*.cc"} }),
        .flags = &.{"-std=c++11"},
    });
    const lib = b.addLibrary(.{ .name = "cairomm-1.0", .root_module = mod, .linkage = .static });
    lib.installHeadersDirectory(upstream.path("cairomm"), "cairomm", .{});
    lib.installConfigHeader(config);
    lib.installLibraryHeaders(sigc);
    b.installArtifact(lib);
}
