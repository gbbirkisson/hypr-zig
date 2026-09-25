const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});
    const sv = std.SemanticVersion.parse(version) catch unreachable;
    const scanner = b.dependency("wayland", .{}).artifact("wayland-scanner");
    const wp = b.dependency("wayland_protocols", .{}).namedLazyPath("root");

    // Upstream also generates ext-session-lock and xdg-dialog, for its tests only.
    const gen = b.addWriteFiles();
    const protos = [_][]const u8{
        util.waylandProtocol(b, scanner, gen, upstream.path("protocol/wlr-layer-shell-unstable-v1.xml"), "wlr-layer-shell-unstable-v1-client.h", "wlr-layer-shell-unstable-v1.c", true),
        util.waylandProtocol(b, scanner, gen, wp.path(b, "stable/xdg-shell/xdg-shell.xml"), "xdg-shell-client.h", "xdg-shell.c", true),
    };

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true });
    mod.addIncludePath(upstream.path("include"));
    mod.addIncludePath(upstream.path("src"));
    mod.addIncludePath(upstream.path("gtk-priv/h"));
    mod.addIncludePath(gen.getDirectory());
    for ([_][2][]const u8{
        .{ "GTK_LAYER_SHELL_MAJOR", b.fmt("{d}", .{sv.major}) },
        .{ "GTK_LAYER_SHELL_MICRO", b.fmt("{d}", .{sv.patch}) },
        .{ "GTK_LAYER_SHELL_MINOR", b.fmt("{d}", .{sv.minor}) },
    }) |m| mod.addCMacro(m[0], m[1]);
    mod.linkLibrary(b.dependency("wayland", .{ .target = target, .optimize = optimize }).artifact("wayland-client"));
    mod.linkSystemLibrary("gtk+-3.0", .{});
    mod.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = try util.glob(b, upstream.path(""), .{ .include = &.{"src/*.c"} }),
        .flags = &.{"-std=gnu11"},
    });
    mod.addCSourceFiles(.{ .root = gen.getDirectory(), .files = &protos, .flags = &.{"-std=gnu11"} });
    const lib = b.addLibrary(.{ .name = "gtk-layer-shell", .root_module = mod, .linkage = .static });
    // Upstream's pkg-config adds include/gtk-layer-shell, so consumers write <gtk-layer-shell.h>.
    lib.installHeader(upstream.path("include/gtk-layer-shell.h"), "gtk-layer-shell.h");
    b.installArtifact(lib);
}
