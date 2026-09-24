const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});
    const sv = std.SemanticVersion.parse(version) catch unreachable;

    const config = b.addConfigHeader(.{ .include_path = "config.h" }, .{
        .HTTP_DOC_LINK = b.fmt("https://wayland.freedesktop.org/libinput/doc/{s}", .{version}),
        ._GNU_SOURCE = 1,
        .HAVE_VERSIONSORT = 1,
        .HAVE_PIDFD_OPEN = 1,
        .HAVE_SIGABBREV_NP = 1,
        .HAVE_LOCALE_H = 1,
        .HAVE_MTDEV = 1,
        .LIBINPUT_QUIRKS_DIR = "/usr/share/libinput",
        .LIBINPUT_QUIRKS_OVERRIDE_FILE = "/etc/libinput/local-overrides.quirks",
        .LIBINPUT_QUIRKS_SRCDIR = "/usr/share/libinput",
        .LIBINPUT_PLUGIN_LIBDIR = "/usr/lib/libinput/plugins",
        .LIBINPUT_PLUGIN_ETCDIR = "/etc/libinput/plugins",
        .LIBINPUT_TOOL_PATH = "/usr/libexec/libinput",
    });
    const version_h = b.addConfigHeader(.{
        .style = .{ .cmake = upstream.path("src/libinput-version.h.in") },
        .include_path = "libinput-version.h",
    }, .{
        .LIBINPUT_VERSION_MAJOR = @as(i64, @intCast(sv.major)),
        .LIBINPUT_VERSION_MINOR = @as(i64, @intCast(sv.minor)),
        .LIBINPUT_VERSION_MICRO = @as(i64, @intCast(sv.patch)),
        .LIBINPUT_VERSION = version,
    });

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true });
    mod.addIncludePath(upstream.path("include"));
    mod.addIncludePath(upstream.path(""));
    mod.addIncludePath(upstream.path("src"));
    mod.addConfigHeader(config);
    mod.addConfigHeader(version_h);
    for ([_][]const u8{
        "libevdev",
        "libudev",
        "m",
        "mtdev",
    }) |l| mod.linkSystemLibrary(l, .{});
    mod.addCSourceFiles(.{
        .root = upstream.path(""),
        // Lua plugins are disabled.
        .files = try util.glob(b, upstream.path(""), .{ .include = &.{"src/*.c"}, .exclude = &.{"src/libinput-plugin-lua.c"} }),
        .flags = &.{
            "-Wno-missing-field-initializers",
            "-Wno-unused-parameter",
            "-fvisibility=hidden",
            "-std=gnu99",
        },
    });

    const lib = b.addLibrary(.{ .name = "input", .root_module = mod, .linkage = .static });
    lib.installHeader(upstream.path("src/libinput.h"), "libinput.h");
    b.installArtifact(lib);
}
