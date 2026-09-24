const std = @import("std");
const util = @import("build_util");

const wayland_protocols = [_][]const u8{
    "stable/linux-dmabuf/linux-dmabuf-v1.xml",
    "staging/ext-foreign-toplevel-list/ext-foreign-toplevel-list-v1.xml",
    "unstable/xdg-output/xdg-output-unstable-v1.xml",
};

const hyprland_protocols = [_][]const u8{
    "protocols/hyprland-global-shortcuts-v1.xml",
    "protocols/hyprland-input-capture-v1.xml",
    "protocols/hyprland-toplevel-export-v1.xml",
    "protocols/hyprland-toplevel-mapping-v1.xml",
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});
    const opts = .{ .target = target, .optimize = optimize };
    const wayland = b.dependency("wayland", opts);
    const scanner = b.dependency("hyprwayland_scanner", .{}).artifact("hyprwayland-scanner");
    const wp = b.dependency("wayland_protocols", .{}).namedLazyPath("root");
    const hp = b.dependency("hyprland_protocols", .{}).namedLazyPath("root");
    const src = util.patched(b, upstream.path(""), &.{b.path("patches/limit-screencast-persist-mode.patch")});

    // A commit pin has no version in its URL; upstream's VERSION file is the source.
    b.dependOnFileContents(upstream.path("VERSION"));
    const version = std.mem.trim(u8, try upstream.builder.root.root_dir.handle.readFileAlloc(b.graph.io, "VERSION", b.allocator, .limited(64)), " \n");

    const gen = b.addWriteFiles();
    var protos: std.ArrayList([]const u8) = .empty;
    for (try util.glob(b, upstream.path(""), .{ .include = &.{"protocols/*.xml"} })) |xml|
        try protos.append(b.allocator, util.hyprwaylandProtocol(b, scanner, gen, upstream.path(xml), std.fs.path.stem(xml), .{ .side = .client }).?);
    for (hyprland_protocols) |xml|
        try protos.append(b.allocator, util.hyprwaylandProtocol(b, scanner, gen, hp.path(b, xml), std.fs.path.stem(xml), .{ .side = .client }).?);
    for (wayland_protocols) |xml|
        try protos.append(b.allocator, util.hyprwaylandProtocol(b, scanner, gen, wp.path(b, xml), std.fs.path.stem(xml), .{ .side = .client }).?);
    try protos.append(b.allocator, util.hyprwaylandProtocol(b, scanner, gen, wayland.namedLazyPath("wayland-xml"), "wayland", .{ .side = .client, .flags = &.{"--wayland-enums"}, .provided = &@import("wayland").protocols }).?);

    const flags: []const []const u8 = &.{
        "-Wno-address-of-temporary",
        "-Wno-keyword-macro",
        "-Wno-missing-field-initializers",
        "-Wno-narrowing",
        "-Wno-pointer-arith",
        "-Wno-unused-parameter",
        "-Wno-unused-value",
        "-std=c++23",
    };

    const portal = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true, .strip = optimize != .debug });
    portal.addIncludePath(src);
    portal.addIncludePath(gen.getDirectory().path(b, "protocols"));
    portal.addCMacro("XDPH_VERSION", b.fmt("\"{s}\"", .{version}));
    for ([_][2][]const u8{
        .{ "hyprlang", "hyprlang" },
        .{ "hyprutils", "hyprutils" },
        .{ "sdbus_cpp", "sdbus-c++" },
    }) |d| portal.linkLibrary(b.dependency(d[0], opts).artifact(d[1]));
    portal.linkLibrary(wayland.artifact("wayland-client"));
    for ([_][]const u8{
        "gbm",
        "libdrm",
        "libpipewire-0.3",
        "libspa-0.2",
        "uuid",
    }) |l| portal.linkSystemLibrary(l, .{});
    // The glob walks the pristine tree (configure time needs a fetched tree); file names match.
    portal.addCSourceFiles(.{ .root = src, .files = try util.glob(b, upstream.path(""), .{ .include = &.{"src/**/*.cpp"} }), .flags = flags });
    portal.addCSourceFiles(.{ .root = gen.getDirectory(), .files = protos.items, .flags = flags });
    const portal_exe = b.addExecutable(.{ .name = "xdg-desktop-portal-hyprland", .root_module = portal });
    portal_exe.rdynamic = true;
    b.installArtifact(portal_exe);

    const picker = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true, .strip = optimize != .debug });
    for ([_][2][]const u8{
        .{ "hyprtoolkit", "hyprtoolkit" },
        .{ "hyprutils", "hyprutils" },
    }) |d| picker.linkLibrary(b.dependency(d[0], opts).artifact(d[1]));
    picker.linkSystemLibrary("libdrm", .{});
    picker.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = try util.glob(b, upstream.path(""), .{
            .include = &.{"hyprland-share-picker/*.cpp"},
            .exclude = &.{"hyprland-share-picker/PickerDataTest.cpp"},
        }),
        .flags = flags,
    });
    const picker_exe = b.addExecutable(.{ .name = "hyprland-share-picker", .root_module = picker });
    picker_exe.rdynamic = true;
    b.installArtifact(picker_exe);

    // Upstream bakes an absolute libexec path; build.zig does not know the prefix, so the binary
    // goes to bin/ and systemd resolves the bare name.
    const data = b.addWriteFiles();
    for ([_][2][]const u8{
        .{ "contrib/systemd/xdg-desktop-portal-hyprland.service.in", "lib/systemd/user/xdg-desktop-portal-hyprland.service" },
        .{ "org.freedesktop.impl.portal.desktop.hyprland.service.in", "share/dbus-1/services/org.freedesktop.impl.portal.desktop.hyprland.service" },
    }) |f| {
        const sed = b.addSystemCommand(&.{ "sed", "s|@LIBEXECDIR@/||" });
        sed.addFileArg(upstream.path(f[0]));
        _ = data.addCopyFile(sed.captureStdOut(.{}), f[1]);
    }
    _ = data.addCopyFile(upstream.path("hyprland.portal"), "share/xdg-desktop-portal/portals/hyprland.portal");
    b.addNamedLazyPath("data", data.getDirectory());
}
