const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

const wayland_protocols = [_][]const u8{
    "stable/linux-dmabuf/linux-dmabuf-v1.xml",
    "stable/tablet/tablet-v2.xml",
    "stable/viewporter/viewporter.xml",
    "staging/cursor-shape/cursor-shape-v1.xml",
    "staging/ext-session-lock/ext-session-lock-v1.xml",
    "staging/fractional-scale/fractional-scale-v1.xml",
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});
    const opts = .{ .target = target, .optimize = optimize };
    const wayland = b.dependency("wayland", opts);
    const scanner = b.dependency("hyprwayland_scanner", .{}).artifact("hyprwayland-scanner");
    const wp = b.dependency("wayland_protocols", .{}).namedLazyPath("root");
    // lld rejects IWidget.cpp's `#pragma comment(lib, "date-tz")`; date-tz is linked below.
    const src = util.patched(b, upstream.path(""), &.{b.path("patches/no-autolink.patch")});

    const gen = b.addWriteFiles();
    var protos: std.ArrayList([]const u8) = .empty;
    for (wayland_protocols) |xml|
        try protos.append(b.allocator, util.hyprwaylandProtocol(b, scanner, gen, wp.path(b, xml), std.fs.path.stem(xml), .{ .side = .client }).?);
    try protos.append(b.allocator, util.hyprwaylandProtocol(b, scanner, gen, upstream.path("protocols/wlr-screencopy-unstable-v1.xml"), "wlr-screencopy-unstable-v1", .{ .side = .client }).?);
    try protos.append(b.allocator, util.hyprwaylandProtocol(b, scanner, gen, wayland.namedLazyPath("wayland-xml"), "wayland", .{ .side = .client, .flags = &.{"--wayland-enums"}, .provided = &@import("wayland").protocols }).?);

    const flags: []const []const u8 = &.{
        "-Wno-keyword-macro",
        "-Wno-missing-field-initializers",
        "-Wno-narrowing",
        "-Wno-unused-parameter",
        "-Wno-unused-value",
        "-std=c++23",
    };
    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true, .strip = optimize != .debug });
    mod.addIncludePath(src);
    mod.addIncludePath(gen.getDirectory().path(b, "protocols"));
    for ([_][2][]const u8{
        .{ "HYPRLOCK_COMMIT", "\"v" ++ version ++ "\"" },
        .{ "HYPRLOCK_VERSION", "\"" ++ version ++ "\"" },
        .{ "HYPRLOCK_VERSION_COMMIT", "\"v" ++ version ++ "\"" },
        .{ "USE_OS_TZDB", "1" },
    }) |m| mod.addCMacro(m[0], m[1]);
    for ([_][2][]const u8{
        .{ "date", "date-tz" },
        .{ "hyprgraphics", "hyprgraphics" },
        .{ "hyprlang", "hyprlang" },
        .{ "hyprutils", "hyprutils" },
        .{ "libxkbcommon", "xkbcommon" },
        .{ "sdbus_cpp", "sdbus-c++" },
    }) |d| mod.linkLibrary(b.dependency(d[0], opts).artifact(d[1]));
    mod.linkLibrary(wayland.artifact("wayland-client"));
    mod.linkLibrary(wayland.artifact("wayland-egl"));
    for ([_][]const u8{
        "cairo",
        "egl",
        "gbm",
        "glesv2",
        "libdrm",
        "pam",
        "pangocairo",
    }) |l| mod.linkSystemLibrary(l, .{});
    // The glob walks the pristine tree (configure time needs a fetched tree); file names match.
    mod.addCSourceFiles(.{ .root = src, .files = try util.glob(b, upstream.path(""), .{ .include = &.{"src/**/*.cpp"} }), .flags = flags });
    mod.addCSourceFiles(.{ .root = gen.getDirectory(), .files = protos.items, .flags = flags });
    const exe = b.addExecutable(.{ .name = "hyprlock", .root_module = mod });
    exe.rdynamic = true;
    b.installArtifact(exe);

    const data = b.addWriteFiles();
    _ = data.addCopyFile(upstream.path("pam/hyprlock"), "etc/pam.d/hyprlock");
    _ = data.addCopyFile(upstream.path("assets/example.conf"), "share/hypr/hyprlock.conf");
    b.addNamedLazyPath("data", data.getDirectory());
}
