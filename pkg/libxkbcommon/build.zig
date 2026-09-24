const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});

    const config = b.addConfigHeader(.{ .include_path = "config.h" }, .{
        .DEFAULT_XKB_LAYOUT = "us",
        .DEFAULT_XKB_MODEL = "pc105",
        .DEFAULT_XKB_OPTIONS = .NULL,
        .DEFAULT_XKB_RULES = "evdev",
        .DEFAULT_XKB_VARIANT = .NULL,
        .DFLT_XKB_CONFIG_EXTRA_PATH = "/etc/xkb",
        .DFLT_XKB_CONFIG_ROOT = "/usr/share/X11/xkb",
        .DFLT_XKB_CONFIG_UNVERSIONED_EXTENSIONS_PATH = "/usr/share/xkeyboard-config.d",
        .DFLT_XKB_CONFIG_VERSIONED_EXTENSIONS_PATH = "/usr/share/X11/xkb.d",
        .DFLT_XKB_LEGACY_ROOT = "/usr/share/X11/xkb",
        .EXIT_INVALID_USAGE = 2,
        .HAVE_ASPRINTF = 1,
        .HAVE_DIRENT_H = 1,
        .HAVE_EACCESS = 1,
        .HAVE_EUIDACCESS = 1,
        .HAVE_MKOSTEMP = 1,
        .HAVE_MMAP = 1,
        .HAVE_NEWLOCALE = 1,
        .HAVE_OPEN_MEMSTREAM = 1,
        .HAVE_POSIX_FALLOCATE = 1,
        .HAVE_REAL_PATH = 1,
        .HAVE_SECURE_GETENV = 1,
        .HAVE_STRNDUP = 1,
        .HAVE_UNISTD_H = 1,
        .HAVE_VASPRINTF = 1,
        .HAVE_XKB_EXTENSIONS_DIRECTORIES = 1,
        .HAVE___BUILTIN_EXPECT = 1,
        .LIBXKBCOMMON_TOOL_PATH = "/usr/libexec/xkbcommon",
        .LIBXKBCOMMON_VERSION = version,
        .XLOCALEDIR = "/usr/share/X11/locale",
        ._GNU_SOURCE = 1,
    });

    const bison = b.addSystemCommand(&.{"bison"});
    const parser_h = bison.addPrefixedOutputFileArg("--defines=", "parser.h");
    bison.addArg("-o");
    const parser_c = bison.addOutputFileArg("parser.c");
    bison.addArgs(&.{ "--no-lines", "-p", "_xkbcommon_" });
    bison.addFileArg(upstream.path("src/xkbcomp/parser.y"));

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true, .sanitize_c = .off });
    mod.addIncludePath(upstream.path(""));
    mod.addIncludePath(upstream.path("src"));
    mod.addIncludePath(upstream.path("include"));
    mod.addIncludePath(parser_h.dirname());
    mod.addConfigHeader(config);
    const flags: []const []const u8 = &.{
        "-Wno-missing-field-initializers",
        "-Wno-unused-parameter",
        "-fno-strict-aliasing",
        "-fvisibility=hidden",
        "-std=c11",
    };
    mod.addCSourceFiles(.{
        .root = upstream.path(""),
        // Core library only: no x11, registry or tools support.
        .files = try util.glob(b, upstream.path(""), .{
            .include = &.{"src/**/*.c"},
            .exclude = &.{
                "src/compose/dump.c",
                "src/keymap-formats.c",
                "src/registry.c",
                "src/util-list.c",
                "src/x11/**",
            },
        }),
        .flags = flags,
    });
    mod.addCSourceFile(.{ .file = parser_c, .flags = flags });

    const lib = b.addLibrary(.{ .name = "xkbcommon", .root_module = mod, .linkage = .static });
    lib.installHeadersDirectory(upstream.path("include/xkbcommon"), "xkbcommon", .{});
    b.installArtifact(lib);
}
