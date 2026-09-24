const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

/// Protocols whose C interface symbols this library defines. Linking another generated copy of them
/// into the same binary duplicates those symbols.
pub const protocols = [_]util.Protocol{
    .{ .name = "linux-dmabuf-v1", .side = .client },
    .{ .name = "wayland", .side = .client },
    .{ .name = "xdg-shell", .side = .client },
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});
    const opts = .{ .target = target, .optimize = optimize };
    const wayland = b.dependency("wayland", opts);
    const wp = b.dependency("wayland_protocols", .{}).namedLazyPath("root");
    const scanner = b.dependency("hyprwayland_scanner", .{}).artifact("hyprwayland-scanner");

    const gen = b.addWriteFiles();
    const protos = [_][]const u8{
        util.hyprwaylandProtocol(b, scanner, gen, wp.path(b, "stable/linux-dmabuf/linux-dmabuf-v1.xml"), "linux-dmabuf-v1", .{ .side = .client }).?,
        util.hyprwaylandProtocol(b, scanner, gen, wayland.namedLazyPath("wayland-xml"), "wayland", .{ .side = .client, .flags = &.{"--wayland-enums"}, .provided = &@import("wayland").protocols }).?,
        util.hyprwaylandProtocol(b, scanner, gen, wp.path(b, "stable/xdg-shell/xdg-shell.xml"), "xdg-shell", .{ .side = .client }).?,
    };

    // hwdata.hpp: data/hwdata.sh turns pnp.ids into table rows spliced into hwdata.hpp.in.
    const hwdata = b.addSystemCommand(&.{
        "sh", "-c",
        \\sh "$1" < "$2" | sed -e '/@HWDATA_PNP_IDS@/{r /dev/stdin' -e 'd}' "$3" > "$4"
        ,
        "sh",
    });
    hwdata.addFileArg(upstream.path("data/hwdata.sh"));
    hwdata.addFileArg(.{ .cwd_relative = "/usr/share/hwdata/pnp.ids" });
    hwdata.addFileArg(upstream.path("data/hwdata.hpp.in"));
    const hwdata_hpp = hwdata.addOutputFileArg("hwdata.hpp");

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true });
    mod.addIncludePath(upstream.path("include"));
    mod.addIncludePath(upstream.path("src"));
    mod.addIncludePath(upstream.path("src/include"));
    mod.addIncludePath(gen.getDirectory().path(b, "protocols"));
    mod.addIncludePath(hwdata_hpp.dirname());
    mod.addCMacro("AQUAMARINE_VERSION", b.fmt("\"{s}\"", .{version}));
    mod.addCMacro("AQUAMARINE_HAS_LIBINPUT_PLUGINS", "");
    mod.linkLibrary(b.dependency("hyprutils", opts).artifact("hyprutils"));
    mod.linkLibrary(b.dependency("libinput", opts).artifact("input"));
    mod.linkLibrary(wayland.artifact("wayland-client"));
    mod.linkLibrary(b.dependency("libdisplay_info", opts).artifact("display-info"));
    for ([_][]const u8{
        "egl",
        "gbm",
        "glesv2",
        "libdrm",
        "libseat",
        "libudev",
        "pixman-1",
    }) |l|
        mod.linkSystemLibrary(l, .{});
    const flags = [_][]const u8{
        "-Wno-missing-field-initializers",
        "-Wno-unused-parameter",
        "-std=c++23",
    };
    mod.addCSourceFiles(.{ .root = upstream.path(""), .files = try util.glob(b, upstream.path(""), .{ .include = &.{"src/**/*.cpp"} }), .flags = &flags });
    mod.addCSourceFiles(.{ .root = gen.getDirectory(), .files = &protos, .flags = &(flags ++ [_][]const u8{"-Wno-keyword-macro"}) });

    const lib = b.addLibrary(.{ .name = "aquamarine", .root_module = mod, .linkage = .static });
    lib.installHeadersDirectory(upstream.path("include"), "", .{ .include_extensions = null });
    b.installArtifact(lib);
}
