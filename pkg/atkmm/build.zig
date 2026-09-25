const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});
    const sv = std.SemanticVersion.parse(version) catch unreachable;
    const glibmm = b.dependency("glibmm", .{ .target = target, .optimize = optimize }).artifact("glibmm-2.4");

    const config = b.addConfigHeader(.{ .style = .{ .meson = upstream.path("atk/atkmmconfig.h.meson") }, .include_path = "atkmmconfig.h" }, .{
        .ATKMM_DISABLE_DEPRECATED = null,
        .ATKMM_MAJOR_VERSION = @as(i64, @intCast(sv.major)),
        .ATKMM_MICRO_VERSION = @as(i64, @intCast(sv.patch)),
        .ATKMM_MINOR_VERSION = @as(i64, @intCast(sv.minor)),
        .ATKMM_STATIC_LIB = 1,
    });

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true });
    mod.addIncludePath(upstream.path("atk"));
    mod.addIncludePath(upstream.path("untracked/atk"));
    mod.addConfigHeader(config);
    mod.addCMacro("ATKMM_BUILD", "1");
    mod.linkLibrary(glibmm);
    mod.linkSystemLibrary("atk", .{});
    mod.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = try util.glob(b, upstream.path(""), .{ .include = &.{
            "atk/atkmm/*.cc",
            "untracked/atk/atkmm/*.cc",
        } }),
        .flags = &.{"-std=c++11"},
    });
    const lib = b.addLibrary(.{ .name = "atkmm-1.6", .root_module = mod, .linkage = .static });
    lib.installHeader(upstream.path("atk/atkmm.h"), "atkmm.h");
    lib.installHeadersDirectory(upstream.path("atk/atkmm"), "atkmm", .{});
    lib.installHeadersDirectory(upstream.path("untracked/atk/atkmm"), "atkmm", .{});
    lib.installConfigHeader(config);
    lib.installLibraryHeaders(glibmm);
    b.installArtifact(lib);
}
