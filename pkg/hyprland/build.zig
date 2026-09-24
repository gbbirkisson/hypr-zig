const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

// The wayland-protocols subset that Hyprland's CMakeLists.txt generates. Diff on every Hyprland bump.
const wayland_protocols = [_][]const u8{
    "stable/linux-dmabuf/linux-dmabuf-v1.xml",
    "stable/presentation-time/presentation-time.xml",
    "stable/tablet/tablet-v2.xml",
    "stable/viewporter/viewporter.xml",
    "stable/xdg-shell/xdg-shell.xml",
    "staging/alpha-modifier/alpha-modifier-v1.xml",
    "staging/color-management/color-management-v1.xml",
    "staging/commit-timing/commit-timing-v1.xml",
    "staging/content-type/content-type-v1.xml",
    "staging/cursor-shape/cursor-shape-v1.xml",
    "staging/drm-lease/drm-lease-v1.xml",
    "staging/ext-background-effect/ext-background-effect-v1.xml",
    "staging/ext-data-control/ext-data-control-v1.xml",
    "staging/ext-foreign-toplevel-list/ext-foreign-toplevel-list-v1.xml",
    "staging/ext-idle-notify/ext-idle-notify-v1.xml",
    "staging/ext-image-capture-source/ext-image-capture-source-v1.xml",
    "staging/ext-image-copy-capture/ext-image-copy-capture-v1.xml",
    "staging/ext-session-lock/ext-session-lock-v1.xml",
    "staging/ext-workspace/ext-workspace-v1.xml",
    "staging/fifo/fifo-v1.xml",
    "staging/fractional-scale/fractional-scale-v1.xml",
    "staging/linux-drm-syncobj/linux-drm-syncobj-v1.xml",
    "staging/pointer-warp/pointer-warp-v1.xml",
    "staging/security-context/security-context-v1.xml",
    "staging/single-pixel-buffer/single-pixel-buffer-v1.xml",
    "staging/tearing-control/tearing-control-v1.xml",
    "staging/xdg-activation/xdg-activation-v1.xml",
    "staging/xdg-dialog/xdg-dialog-v1.xml",
    "staging/xdg-system-bell/xdg-system-bell-v1.xml",
    "staging/xdg-toplevel-tag/xdg-toplevel-tag-v1.xml",
    "staging/xwayland-shell/xwayland-shell-v1.xml",
    "unstable/idle-inhibit/idle-inhibit-unstable-v1.xml",
    "unstable/keyboard-shortcuts-inhibit/keyboard-shortcuts-inhibit-unstable-v1.xml",
    "unstable/pointer-constraints/pointer-constraints-unstable-v1.xml",
    "unstable/pointer-gestures/pointer-gestures-unstable-v1.xml",
    "unstable/primary-selection/primary-selection-unstable-v1.xml",
    "unstable/relative-pointer/relative-pointer-unstable-v1.xml",
    "unstable/text-input/text-input-unstable-v1.xml",
    "unstable/text-input/text-input-unstable-v3.xml",
    "unstable/xdg-decoration/xdg-decoration-unstable-v1.xml",
    "unstable/xdg-foreign/xdg-foreign-unstable-v2.xml",
    "unstable/xdg-output/xdg-output-unstable-v1.xml",
};

const shader_script =
    \\set -e
    \\src=$1; out=$2
    \\mkdir -p "$out"
    \\h="$out/Shaders.hpp"
    \\printf '%s\n' '#pragma once' '#include <algorithm>' '#include <array>' '#include <string_view>' '#include <utility>' \
    \\  'inline constexpr auto SHADERS = [](auto shaders) {' \
    \\  'std::ranges::sort(shaders, {}, [](auto pair) { return pair.first; });' \
    \\  'return shaders;' \
    \\  '}(std::to_array<std::pair<std::string_view, std::string_view>>({' > "$h"
    \\for f in "$src"/*; do
    \\  n=${f##*/}
    \\  { printf 'R"#('; cat "$f"; printf ')#"\n'; } > "$out/$n.inc"
    \\  printf '{"%s",\n#include "./%s.inc"\n},\n' "$n" "$n" >> "$h"
    \\done
    \\printf '}));\n' >> "$h"
;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});
    const opts = .{ .target = target, .optimize = optimize };

    const gen = b.addWriteFiles();

    // Protocols.
    const scanner = b.dependency("hyprwayland_scanner", .{}).artifact("hyprwayland-scanner");
    const hp = b.dependency("hyprland_protocols", .{}).namedLazyPath("root");
    const wp = b.dependency("wayland_protocols", .{}).namedLazyPath("root");
    const wayland = b.dependency("wayland", opts);
    const aq_protocols = &(@import("aquamarine").protocols ++ @import("wayland").protocols);
    var proto_srcs: std.ArrayList([]const u8) = .empty;
    for (try util.glob(b, upstream.path(""), .{ .include = &.{"protocols/*.xml"} })) |xml|
        if (util.hyprwaylandProtocol(b, scanner, gen, upstream.path(xml), std.fs.path.stem(xml), .{ .side = .server, .provided = aq_protocols })) |c| try proto_srcs.append(b.allocator, c);
    for (try util.glob(b, hp, .{ .include = &.{"protocols/*.xml"} })) |xml|
        if (util.hyprwaylandProtocol(b, scanner, gen, hp.path(b, xml), std.fs.path.stem(xml), .{ .side = .server, .provided = aq_protocols })) |c| try proto_srcs.append(b.allocator, c);
    for (wayland_protocols) |xml|
        if (util.hyprwaylandProtocol(b, scanner, gen, wp.path(b, xml), std.fs.path.stem(xml), .{ .side = .server, .provided = aq_protocols })) |c| try proto_srcs.append(b.allocator, c);
    if (util.hyprwaylandProtocol(b, scanner, gen, wayland.namedLazyPath("wayland-xml"), "wayland", .{ .side = .server, .flags = &.{"--wayland-enums"}, .provided = aq_protocols })) |c| try proto_srcs.append(b.allocator, c);

    // Shaders.
    const shaders = b.addSystemCommand(&.{ "sh", "-c", shader_script, "sh" });
    shaders.addDirectoryArg(upstream.path("src/render/shaders/glsl"));
    _ = gen.addCopyDirectory(shaders.addOutputDirectoryArg("shaders"), "src/render/shaders", .{});

    // version.h.
    const aq = std.SemanticVersion.parse(@import("aquamarine").version) catch unreachable;
    const version_h = b.addConfigHeader(.{ .style = .{ .cmake = upstream.path("src/version.h.in") } }, .{
        .GIT_COMMIT_HASH = "unknown",
        .GIT_BRANCH = "unknown",
        .GIT_COMMIT_MESSAGE = "unknown",
        .GIT_COMMIT_DATE = "unknown",
        .GIT_DIRTY = "unknown",
        .GIT_TAG = "v" ++ version,
        .GIT_COMMITS = "0",
        .AQUAMARINE_VERSION = @import("aquamarine").version,
        .AQUAMARINE_VERSION_MAJOR = @as(i64, @intCast(aq.major)),
        .AQUAMARINE_VERSION_MINOR = @as(i64, @intCast(aq.minor)),
        .AQUAMARINE_VERSION_PATCH = @as(i64, @intCast(aq.patch)),
        .HYPRLANG_VERSION = @import("hyprlang").version,
        .HYPRUTILS_VERSION = @import("hyprutils").version,
        .HYPRCURSOR_VERSION = @import("hyprcursor").version,
        .HYPRGRAPHICS_VERSION = @import("hyprgraphics").version,
    });
    _ = gen.addCopyFile(version_h.getOutputFile(), "src/version.h");

    const gen_step = b.step("gen", "Generate Hyprland sources");
    gen_step.dependOn(&b.addInstallDirectory(.{
        .source_dir = gen.getDirectory(),
        .install_dir = .prefix,
        .install_subdir = "gen",
    }).step);

    // Plugin hooks resolve symbols with `nm -D`, which reads .dynsym (kept by rdynamic), so stripping is safe.
    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true, .strip = optimize != .debug });
    // Generated files are included by relative paths ("../version.h", "shaders/Shaders.hpp",
    // "../../protocols/cursor-shape-v1.hpp"); these two include dirs make all of them resolve in `gen`.
    mod.addIncludePath(gen.getDirectory().path(b, "protocols"));
    mod.addIncludePath(gen.getDirectory().path(b, "src/render"));
    mod.addIncludePath(upstream.path(""));
    mod.addIncludePath(upstream.path("src"));
    mod.addIncludePath(b.dependency("glaze", .{}).namedLazyPath("include"));
    mod.addCMacro("HYPRLAND_VERSION", "\"" ++ version ++ "\"");
    mod.addCMacro("NO_XWAYLAND", "");
    mod.addCMacro("USES_SYSTEMD", "");
    mod.addCMacro("HAS_EXECINFO", "");
    mod.addCMacro("MUPARSER_STATIC", "");

    for ([_][2][]const u8{
        .{ "aquamarine", "aquamarine" },
        .{ "glslang", "glslang" },
        .{ "glslang", "glslang-default-resource-limits" },
        .{ "hyprcursor", "hyprcursor" },
        .{ "hyprgraphics", "hyprgraphics" },
        .{ "hyprlang", "hyprlang" },
        .{ "hyprutils", "hyprutils" },
        .{ "libinput", "input" },
        .{ "libxkbcommon", "xkbcommon" },
        .{ "lua", "lua" },
        .{ "muparser", "muparser" },
        .{ "re2", "re2" },
        .{ "udis86", "udis86" },
    }) |d| mod.linkLibrary(b.dependency(d[0], opts).artifact(d[1]));
    mod.linkLibrary(wayland.artifact("wayland-server"));
    for ([_][]const u8{
        "cairo",
        "egl",
        "gbm",
        "gio-2.0",
        "glesv2",
        "lcms2",
        "libdrm",
        "libeis-1.0",
        "pango",
        "pangocairo",
        "pixman-1",
        "uuid",
        "xcursor",
    }) |l| mod.linkSystemLibrary(l, .{});

    const flags: []const []const u8 = &.{
        "-Wno-c23-extensions",
        "-Wno-gnu-zero-variadic-macro-arguments",
        "-Wno-keyword-macro",
        "-Wno-missing-field-initializers",
        "-Wno-narrowing",
        "-Wno-pointer-arith",
        "-Wno-unused-parameter",
        "-Wno-unused-result",
        "-Wno-unused-value",
        "-frtti",
        "-std=c++26",
    };
    // XWM.cpp includes xcb headers before its NO_XWAYLAND guard; everything after is guarded.
    mod.addCSourceFiles(.{ .root = upstream.path(""), .files = try util.glob(b, upstream.path(""), .{ .include = &.{"src/**/*.cpp"}, .exclude = &.{"src/xwayland/XWM.cpp"} }), .flags = flags });
    mod.addCSourceFiles(.{ .root = gen.getDirectory(), .files = proto_srcs.items, .flags = flags });

    const exe = b.addExecutable(.{ .name = "Hyprland", .root_module = mod });
    exe.rdynamic = true;
    b.installArtifact(exe);

    const hw_scanner = b.dependency("hyprwire", .{}).artifact("hyprwire-scanner");
    const hw_gen = b.addWriteFiles();
    const hyprpaper_client = util.hyprwireProtocol(b, hw_scanner, hw_gen, upstream.path("hyprctl/hw-protocols/hyprpaper_core.xml"), "hyprpaper_core", .client);

    const ctl = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true, .strip = optimize != .debug });
    ctl.addIncludePath(hw_gen.getDirectory());
    for ([_][2][]const u8{
        .{ "hyprutils", "hyprutils" },
        .{ "hyprwire", "hyprwire" },
        .{ "re2", "re2" },
    }) |d| ctl.linkLibrary(b.dependency(d[0], opts).artifact(d[1]));
    ctl.linkSystemLibrary("readline", .{});
    ctl.addCSourceFiles(.{ .root = upstream.path(""), .files = try util.glob(b, upstream.path(""), .{ .include = &.{"hyprctl/src/**/*.cpp"} }), .flags = flags });
    ctl.addCSourceFiles(.{ .root = hw_gen.getDirectory(), .files = &.{hyprpaper_client}, .flags = flags });
    const hyprctl = b.addExecutable(.{ .name = "hyprctl", .root_module = ctl });
    hyprctl.rdynamic = true;
    b.installArtifact(hyprctl);

    const start = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true, .strip = optimize != .debug });
    start.addIncludePath(b.dependency("glaze", .{}).namedLazyPath("include"));
    start.linkLibrary(b.dependency("hyprutils", opts).artifact("hyprutils"));
    start.addCSourceFiles(.{ .root = upstream.path(""), .files = try util.glob(b, upstream.path(""), .{ .include = &.{"start/src/**/*.cpp"} }), .flags = flags });
    const start_exe = b.addExecutable(.{ .name = "start-hyprland", .root_module = start });
    start_exe.rdynamic = true;
    b.installArtifact(start_exe);

    const stubs = b.addSystemCommand(&.{"python3"});
    stubs.addFileArg(upstream.path("meta/generateLuaStubs.py"));
    stubs.addArg("--root");
    stubs.addDirectoryArg(upstream.path(""));
    stubs.addArg("--output");
    const stubs_lua = stubs.addOutputFileArg("hl.meta.lua");

    const data = b.addWriteFiles();
    _ = data.addCopyDirectory(upstream.path("assets/install"), "share/hypr", .{});
    for ([_][2][]const u8{
        .{ "assets/hyprland-portals.conf", "share/xdg-desktop-portal/hyprland-portals.conf" },
        .{ "docs/Hyprland.1", "share/man/man1/Hyprland.1" },
        .{ "docs/hyprctl.1", "share/man/man1/hyprctl.1" },
        .{ "example/hyprland.lua", "share/hypr/hyprland.lua" },
        .{ "hyprctl/hyprctl.bash", "share/bash-completion/completions/hyprctl" },
        .{ "hyprctl/hyprctl.fish", "share/fish/vendor_completions.d/hyprctl.fish" },
        .{ "hyprctl/hyprctl.zsh", "share/zsh/site-functions/_hyprctl" },
        .{ "systemd/hyprland-uwsm.desktop", "share/wayland-sessions/hyprland-uwsm.desktop" },
    }) |f| _ = data.addCopyFile(upstream.path(f[0]), f[1]);
    _ = data.addCopyFile(stubs_lua, "share/hypr/stubs/hl.meta.lua");
    _ = data.add("share/wayland-sessions/hyprland.desktop", desktop);
    b.addNamedLazyPath("data", data.getDirectory());
}

// Upstream's example/hyprland.desktop.in with the prefix left to PATH lookup; build.zig does not
// know the install prefix.
const desktop =
    \\[Desktop Entry]
    \\Name=Hyprland
    \\Comment=An intelligent dynamic tiling Wayland compositor
    \\Exec=start-hyprland
    \\Type=Application
    \\DesktopNames=Hyprland
    \\Keywords=tiling;wayland;compositor;
    \\
;
