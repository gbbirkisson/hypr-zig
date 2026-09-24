const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

const wayland_protocols = [_][]const u8{
    "stable/linux-dmabuf/linux-dmabuf-v1.xml",
    "stable/tablet/tablet-v2.xml",
    "stable/viewporter/viewporter.xml",
    "stable/xdg-shell/xdg-shell.xml",
    "staging/cursor-shape/cursor-shape-v1.xml",
    "staging/ext-session-lock/ext-session-lock-v1.xml",
    "staging/fractional-scale/fractional-scale-v1.xml",
    "staging/linux-drm-syncobj/linux-drm-syncobj-v1.xml",
    "unstable/keyboard-shortcuts-inhibit/keyboard-shortcuts-inhibit-unstable-v1.xml",
    "unstable/text-input/text-input-unstable-v3.xml",
};

// Upstream's generateShaderIncludes.sh writes into its working directory; same output here.
const shader_script =
    \\set -e
    \\src=$1; out=$2
    \\mkdir -p "$out"
    \\h="$out/Shaders.hpp"
    \\printf '%s\n' '#pragma once' '#include <map>' 'static const std::map<std::string, std::string> SHADERS = {' > "$h"
    \\for f in "$src"/*; do
    \\  n=${f##*/}
    \\  { printf 'R"#(\n'; cat "$f"; printf '\n)#"\n'; } > "$out/$n.inc"
    \\  printf '{"%s",\n#include "./%s.inc"\n},\n' "$n" "$n" >> "$h"
    \\done
    \\printf '};\n' >> "$h"
;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});
    const opts = .{ .target = target, .optimize = optimize };
    const wayland = b.dependency("wayland", opts);
    const scanner = b.dependency("hyprwayland_scanner", .{}).artifact("hyprwayland-scanner");
    const wp = b.dependency("wayland_protocols", .{}).namedLazyPath("root");
    const provided = &(@import("aquamarine").protocols ++ @import("wayland").protocols);
    // PANGO_WRAP_NONE needs pango 1.56; Ubuntu 24.04 has 1.52.
    const src = util.patched(b, upstream.path(""), &.{b.path("patches/pango-wrap-none.patch")});

    const gen = b.addWriteFiles();
    var protos: std.ArrayList([]const u8) = .empty;
    for (wayland_protocols) |xml|
        if (util.hyprwaylandProtocol(b, scanner, gen, wp.path(b, xml), std.fs.path.stem(xml), .{ .side = .client, .provided = provided })) |c| try protos.append(b.allocator, c);
    if (util.hyprwaylandProtocol(b, scanner, gen, upstream.path("protocols/wlr-layer-shell-unstable-v1.xml"), "wlr-layer-shell-unstable-v1", .{ .side = .client, .provided = provided })) |c| try protos.append(b.allocator, c);
    if (util.hyprwaylandProtocol(b, scanner, gen, wayland.namedLazyPath("wayland-xml"), "wayland", .{ .side = .client, .flags = &.{"--wayland-enums"}, .provided = provided })) |c| try protos.append(b.allocator, c);

    const shaders = b.addSystemCommand(&.{ "sh", "-c", shader_script, "sh" });
    shaders.addDirectoryArg(upstream.path("src/renderer/gl/shaders/glsl"));
    _ = gen.addCopyDirectory(shaders.addOutputDirectoryArg("shaders"), "shaders", .{});

    const flags: []const []const u8 = &.{
        "-Wno-gnu-zero-variadic-macro-arguments",
        "-Wno-keyword-macro",
        "-Wno-missing-braces",
        "-Wno-missing-field-initializers",
        "-Wno-unused-parameter",
        "-Wno-unused-value",
        "-std=c++23",
    };
    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true });
    mod.addIncludePath(upstream.path("include"));
    mod.addIncludePath(src.path(b, "src"));
    mod.addIncludePath(gen.getDirectory());
    mod.addIncludePath(gen.getDirectory().path(b, "protocols"));
    // Debian and Ubuntu ship iniparser without a .pc file.
    mod.addIncludePath(.{ .cwd_relative = "/usr/include/iniparser" });
    mod.linkSystemLibrary("iniparser", .{ .use_pkg_config = .no });
    mod.addCMacro("HT_HIDDEN", "public");
    mod.addCMacro("HYPRTOOLKIT_VERSION", b.fmt("\"{s}\"", .{version}));
    for ([_][2][]const u8{
        .{ "abseil", "absl" },
        .{ "hyprlang", "hyprlang" },
        .{ "libxkbcommon", "xkbcommon" },
    }) |d| mod.linkLibrary(b.dependency(d[0], opts).artifact(d[1]));
    // Public headers include these, as upstream's pkg-config Requires.
    const public = [_]*std.Build.Step.Compile{
        b.dependency("aquamarine", opts).artifact("aquamarine"),
        b.dependency("hyprgraphics", opts).artifact("hyprgraphics"),
        b.dependency("hyprutils", opts).artifact("hyprutils"),
    };
    for (public) |l| mod.linkLibrary(l);
    mod.linkLibrary(wayland.artifact("wayland-client"));
    for ([_][]const u8{
        "cairo",
        "egl",
        "gbm",
        "glesv2",
        "libdrm",
        "pango",
        "pangocairo",
        "pixman-1",
    }) |l| mod.linkSystemLibrary(l, .{});
    // The glob walks the pristine tree (configure time needs a fetched tree); file names match.
    mod.addCSourceFiles(.{ .root = src, .files = try util.glob(b, upstream.path(""), .{ .include = &.{"src/**/*.cpp"} }), .flags = flags });
    mod.addCSourceFiles(.{ .root = gen.getDirectory(), .files = protos.items, .flags = flags });
    const lib = b.addLibrary(.{ .name = "hyprtoolkit", .root_module = mod, .linkage = .static });
    lib.installHeadersDirectory(upstream.path("include"), "", .{ .include_extensions = null });
    for (public) |l| lib.installLibraryHeaders(l);
    b.installArtifact(lib);
}
