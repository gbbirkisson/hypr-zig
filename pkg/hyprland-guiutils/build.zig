const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});
    const opts = .{ .target = target, .optimize = optimize };
    const flags: []const []const u8 = &.{
        "-Wno-missing-field-initializers",
        "-Wno-narrowing",
        "-Wno-unused-parameter",
        "-Wno-unused-value",
        "-std=c++23",
    };

    for ([_][]const u8{
        "dialog",
        "donate-screen",
        "run",
        "update-screen",
        "welcome",
    }) |u| {
        const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true, .strip = optimize != .debug });
        mod.addCMacro("GUIUTILS_VERSION", b.fmt("\"{s}\"", .{version}));
        for ([_][2][]const u8{
            .{ "hyprlang", "hyprlang" },
            .{ "hyprtoolkit", "hyprtoolkit" },
            .{ "hyprutils", "hyprutils" },
            .{ "libxkbcommon", "xkbcommon" },
        }) |d| mod.linkLibrary(b.dependency(d[0], opts).artifact(d[1]));
        mod.addCSourceFiles(.{
            .root = upstream.path(""),
            .files = try util.glob(b, upstream.path(""), .{ .include = &.{b.fmt("utils/{s}/src/**/*.cpp", .{u})} }),
            .flags = flags,
        });
        const exe = b.addExecutable(.{ .name = b.fmt("hyprland-{s}", .{u}), .root_module = mod });
        exe.rdynamic = true;
        b.installArtifact(exe);
    }
    b.addNamedLazyPath("data", b.addWriteFiles().getDirectory());
}
