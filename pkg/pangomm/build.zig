const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});
    const opts = .{ .target = target, .optimize = optimize };
    const sv = std.SemanticVersion.parse(version) catch unreachable;

    const config = b.addConfigHeader(.{ .style = .{ .meson = upstream.path("pango/pangommconfig.h.meson") }, .include_path = "pangommconfig.h" }, .{
        .PANGOMM_DISABLE_DEPRECATED = null,
        .PANGOMM_MAJOR_VERSION = @as(i64, @intCast(sv.major)),
        .PANGOMM_MICRO_VERSION = @as(i64, @intCast(sv.patch)),
        .PANGOMM_MINOR_VERSION = @as(i64, @intCast(sv.minor)),
    });

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true });
    mod.addIncludePath(upstream.path("pango"));
    mod.addIncludePath(upstream.path("untracked/pango"));
    mod.addConfigHeader(config);
    mod.addCMacro("PANGOMM_BUILD", "1");
    // As upstream's pkg-config Requires: pangomm's headers include these.
    const public = [_]*std.Build.Step.Compile{
        b.dependency("cairomm", opts).artifact("cairomm-1.0"),
        b.dependency("glibmm", opts).artifact("glibmm-2.4"),
    };
    for (public) |l| mod.linkLibrary(l);
    mod.linkSystemLibrary("pangocairo", .{});
    mod.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = try util.glob(b, upstream.path(""), .{ .include = &.{
            "pango/pangomm/*.cc",
            "untracked/pango/pangomm/*.cc",
        } }),
        .flags = &.{"-std=c++11"},
    });
    const lib = b.addLibrary(.{ .name = "pangomm-1.4", .root_module = mod, .linkage = .static });
    lib.installHeader(upstream.path("pango/pangomm.h"), "pangomm.h");
    lib.installHeadersDirectory(upstream.path("pango/pangomm"), "pangomm", .{});
    lib.installHeadersDirectory(upstream.path("untracked/pango/pangomm"), "pangomm", .{});
    lib.installConfigHeader(config);
    for (public) |l| lib.installLibraryHeaders(l);
    b.installArtifact(lib);
}
