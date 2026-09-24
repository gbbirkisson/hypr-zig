const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});
    const opts = .{ .target = target, .optimize = optimize };
    const wayland = b.dependency("wayland", opts);
    const scanner = b.dependency("hyprwayland_scanner", .{}).artifact("hyprwayland-scanner");
    const wp = b.dependency("wayland_protocols", .{}).namedLazyPath("root");
    const hp = b.dependency("hyprland_protocols", .{}).namedLazyPath("root");

    const gen = b.addWriteFiles();
    const protos = [_][]const u8{
        util.hyprwaylandProtocol(b, scanner, gen, wp.path(b, "staging/ext-idle-notify/ext-idle-notify-v1.xml"), "ext-idle-notify-v1", .{ .side = .client }).?,
        util.hyprwaylandProtocol(b, scanner, gen, hp.path(b, "protocols/hyprland-lock-notify-v1.xml"), "hyprland-lock-notify-v1", .{ .side = .client }).?,
        util.hyprwaylandProtocol(b, scanner, gen, wayland.namedLazyPath("wayland-xml"), "wayland", .{ .side = .client, .flags = &.{"--wayland-enums"}, .provided = &@import("wayland").protocols }).?,
    };
    const flags: []const []const u8 = &.{
        "-Wno-keyword-macro",
        "-Wno-missing-field-initializers",
        "-Wno-unused-parameter",
        "-Wno-unused-value",
        "-std=c++23",
    };

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true, .strip = optimize != .debug });
    mod.addIncludePath(upstream.path(""));
    mod.addIncludePath(gen.getDirectory().path(b, "protocols"));
    mod.addCMacro("HYPRIDLE_VERSION", b.fmt("\"{s}\"", .{version}));
    for ([_][2][]const u8{
        .{ "hyprlang", "hyprlang" },
        .{ "hyprutils", "hyprutils" },
        .{ "sdbus_cpp", "sdbus-c++" },
    }) |d| mod.linkLibrary(b.dependency(d[0], opts).artifact(d[1]));
    mod.linkLibrary(wayland.artifact("wayland-client"));
    mod.addCSourceFiles(.{ .root = upstream.path(""), .files = try util.glob(b, upstream.path(""), .{ .include = &.{"src/**/*.cpp"} }), .flags = flags });
    mod.addCSourceFiles(.{ .root = gen.getDirectory(), .files = &protos, .flags = flags });
    const exe = b.addExecutable(.{ .name = "hypridle", .root_module = mod });
    exe.rdynamic = true;
    b.installArtifact(exe);

    const unit = b.addSystemCommand(&.{ "sed", "s|@CMAKE_INSTALL_PREFIX@/bin/||" });
    unit.addFileArg(upstream.path("systemd/hypridle.service.in"));
    const data = b.addWriteFiles();
    _ = data.addCopyFile(unit.captureStdOut(.{}), "lib/systemd/user/hypridle.service");
    _ = data.addCopyFile(upstream.path("assets/example.conf"), "share/hypr/hypridle.conf");
    b.addNamedLazyPath("data", data.getDirectory());
}
