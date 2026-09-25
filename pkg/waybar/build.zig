const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

const local_protocols = [_][]const u8{
    "dwl-ipc-unstable-v2",
    "river-control-unstable-v1",
    "river-status-unstable-v1",
    "wlr-foreign-toplevel-management-unstable-v1",
};

// Meson also generates stable/xdg-shell; no source uses it and gtk-layer-shell compiles its own.
const wayland_protocols = [_][]const u8{
    "staging/ext-workspace/ext-workspace-v1.xml",
    "unstable/idle-inhibit/idle-inhibit-unstable-v1.xml",
    "unstable/xdg-output/xdg-output-unstable-v1.xml",
};

// StatusNotifier and DBusMenu interfaces for the tray.
const dbus_interfaces = [_][]const u8{
    "dbus-menu",
    "dbus-status-notifier-item",
    "dbus-status-notifier-watcher",
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});
    const opts = .{ .target = target, .optimize = optimize };
    const scanner = b.dependency("wayland", .{}).artifact("wayland-scanner");
    const wp = b.dependency("wayland_protocols", .{}).namedLazyPath("root");

    const gen = b.addWriteFiles();
    var c_srcs: std.ArrayList([]const u8) = .empty;
    for (local_protocols) |p| try c_srcs.append(b.allocator, util.waylandProtocol(
        b,
        scanner,
        gen,
        upstream.path(b.fmt("protocol/{s}.xml", .{p})),
        b.fmt("{s}-client-protocol.h", .{p}),
        b.fmt("{s}-protocol.c", .{p}),
        false,
    ));
    for (wayland_protocols) |xml| {
        const stem = std.fs.path.stem(xml);
        try c_srcs.append(b.allocator, util.waylandProtocol(
            b,
            scanner,
            gen,
            wp.path(b, xml),
            b.fmt("{s}-client-protocol.h", .{stem}),
            b.fmt("{s}-protocol.c", .{stem}),
            false,
        ));
    }
    // gdbus-codegen and glib-compile-resources come from apt's libglib2.0-dev-bin, matching the
    // linked system glib; mise's glib-tools could emit calls into a newer glib.
    for (dbus_interfaces) |name| {
        for ([_][2][]const u8{
            .{ "--body", ".c" },
            .{ "--header", ".h" },
        }) |m| {
            const run = b.addSystemCommand(&.{ "gdbus-codegen", "--c-namespace", "Sn", m[0], "--output" });
            const out = b.fmt("{s}{s}", .{ name, m[1] });
            _ = gen.addCopyFile(run.addOutputFileArg(out), out);
            run.addFileArg(upstream.path(b.fmt("protocol/{s}.xml", .{name})));
        }
        try c_srcs.append(b.allocator, b.fmt("{s}.c", .{name}));
    }
    // xml-stripblanks runs xmllint (mise, conda:libxml2).
    const resources = b.addSystemCommand(&.{ "glib-compile-resources", "--c-name", "waybar_icons", "--internal", "--generate", "--target" });
    const icons = resources.addOutputFileArg("icon-resources.c");
    resources.addPrefixedDirectoryArg("--sourcedir=", upstream.path("resources/icons"));
    resources.addFileArg(upstream.path("resources/icons/waybar_icons.gresource.xml"));

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true, .strip = optimize != .debug });
    mod.addIncludePath(upstream.path("include"));
    mod.addIncludePath(gen.getDirectory());
    mod.addCMacro("SYSCONFDIR", "\"/etc\"");
    mod.addCMacro("VERSION", b.fmt("\"{s}\"", .{version}));
    // Meson's defines for this configuration (Linux; dbusmenu, pulseaudio, libudev, rfkill on), plus
    // the SPDLOG_* and USE_OS_TZDB Cflags spdlog's and date's pkg-config files would add.
    for ([_][]const u8{
        "HAVE_CPU_LINUX",
        "HAVE_DBUSMENU",
        "HAVE_DWL",
        "HAVE_EXT_WORKSPACES",
        "HAVE_HYPRLAND",
        "HAVE_LANGINFO_1STDAY",
        "HAVE_LIBDATE",
        "HAVE_LIBPULSE",
        "HAVE_LIBUDEV",
        "HAVE_MEMORY_LINUX",
        "HAVE_RIVER",
        "HAVE_SWAY",
        "HAVE_SYSTEMD_MONITOR",
        "HAVE_WAYFIRE",
        "HAVE_WLR_TASKBAR",
        "SPDLOG_COMPILED_LIB",
        "SPDLOG_FMT_EXTERNAL",
        "USE_OS_TZDB",
        "WANT_RFKILL",
    }) |d| mod.addCMacro(d, "1");
    for ([_][2][]const u8{
        .{ "date", "date-tz" },
        .{ "gtk_layer_shell", "gtk-layer-shell" },
        .{ "gtkmm", "gtkmm-3.0" },
        .{ "jsoncpp", "jsoncpp" },
        // Only the registry: xkbcommon also compiles utils.c, and waybar calls no xkb_* function.
        .{ "libxkbcommon", "xkbregistry" },
        .{ "spdlog", "spdlog" },
        .{ "wayland", "wayland-client" },
    }) |d| mod.linkLibrary(b.dependency(d[0], opts).artifact(d[1]));
    for ([_][]const u8{
        "dbusmenu-gtk3-0.4",
        "gio-unix-2.0",
        "gtk+-3.0",
        "libpulse",
        "libudev",
    }) |l| mod.linkSystemLibrary(l, .{});
    // SleeperThread::stop cancels threads, which glibc unwinds with libgcc_s. Zig's own libunwind
    // cannot walk libgcc's frames (null call), so take _Unwind_* from libgcc_s. Zig drops -lgcc_s,
    // hence the path.
    mod.addObjectFile(.{ .cwd_relative = b.fmt("/usr/lib/{s}-linux-gnu/libgcc_s.so.1", .{@tagName(target.result.cpu.arch)}) });
    mod.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = try util.glob(b, upstream.path(""), .{
            .include = &.{"src/**/*.cpp"},
            // Disabled features and other platforms; the rest equals meson's list.
            .exclude = &.{
                "src/modules/cava/cavaGLSL.cpp",
                "src/modules/cava/cavaRaw.cpp",
                "src/modules/cava/cava_backend.cpp",
                "src/modules/cpu_frequency/bsd.cpp",
                "src/modules/cpu_usage/bsd.cpp",
                "src/modules/gamemode.cpp",
                "src/modules/gps.cpp",
                "src/modules/inhibitor.cpp",
                "src/modules/jack.cpp",
                "src/modules/keyboard_state.cpp",
                "src/modules/memory/bsd.cpp",
                "src/modules/mpd/mpd.cpp",
                "src/modules/mpd/state.cpp",
                "src/modules/mpris/mpris.cpp",
                "src/modules/network.cpp",
                "src/modules/niri/backend.cpp",
                "src/modules/niri/language.cpp",
                "src/modules/niri/window.cpp",
                "src/modules/niri/workspaces.cpp",
                "src/modules/privacy/privacy.cpp",
                "src/modules/privacy/privacy_item.cpp",
                "src/modules/simpleclock.cpp",
                "src/modules/sndio.cpp",
                "src/modules/upower.cpp",
                "src/modules/wireplumber.cpp",
                "src/util/pipewire/pipewire_backend.cpp",
                "src/util/pipewire/privacy_node_info.cpp",
            },
        }),
        // fmt 12 deprecates an operator every spdlog call site instantiates.
        .flags = &.{ "-std=c++20", "-Wno-deprecated-declarations" },
    });
    mod.addCSourceFiles(.{ .root = gen.getDirectory(), .files = c_srcs.items, .flags = &.{"-std=c11"} });
    // Registers itself from a constructor, so it must be an object of the executable.
    mod.addCSourceFile(.{ .file = icons, .flags = &.{"-std=c11"} });

    const exe = b.addExecutable(.{ .name = "waybar", .root_module = mod });
    // GTK and Mesa from apt bind to libwayland-client; export the static copy's symbols.
    exe.rdynamic = true;
    b.installArtifact(exe);

    const data = b.addWriteFiles();
    for ([_][]const u8{
        "config.jsonc",
        "style.css",
    }) |f| _ = data.addCopyFile(upstream.path(b.fmt("resources/{s}", .{f})), b.fmt("etc/xdg/waybar/{s}", .{f}));
    b.addNamedLazyPath("data", data.getDirectory());
}
