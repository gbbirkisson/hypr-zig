const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});
    const sv = std.SemanticVersion.parse(version) catch unreachable;

    // Results of upstream's tools/*.cc compiler probes; clang passes all but the Sun one.
    const config = b.addConfigHeader(.{ .style = .{ .meson = upstream.path("sigc++config.h.meson") }, .include_path = "sigc++config.h" }, .{
        .SIGCXX_DISABLE_DEPRECATED = null,
        .SIGCXX_MAJOR_VERSION = @as(i64, @intCast(sv.major)),
        .SIGCXX_MICRO_VERSION = @as(i64, @intCast(sv.patch)),
        .SIGCXX_MINOR_VERSION = @as(i64, @intCast(sv.minor)),
        .SIGC_GCC_TEMPLATE_SPECIALIZATION_OPERATOR_OVERLOAD = true,
        .SIGC_HAVE_SUN_REVERSE_ITERATOR = null,
        .SIGC_MSVC_TEMPLATE_SPECIALIZATION_OPERATOR_OVERLOAD = true,
        .SIGC_PRAGMA_PUSH_POP_MACRO = true,
    });

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true });
    mod.addIncludePath(upstream.path(""));
    mod.addIncludePath(upstream.path("untracked"));
    mod.addConfigHeader(config);
    mod.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = try util.glob(b, upstream.path(""), .{ .include = &.{
            "sigc++/**/*.cc",
            "untracked/sigc++/**/*.cc",
        } }),
        .flags = &.{"-std=c++11"},
    });
    const lib = b.addLibrary(.{ .name = "sigc-2.0", .root_module = mod, .linkage = .static });
    lib.installHeadersDirectory(upstream.path("sigc++"), "sigc++", .{});
    lib.installHeadersDirectory(upstream.path("untracked/sigc++"), "sigc++", .{});
    lib.installConfigHeader(config);
    b.installArtifact(lib);
}
