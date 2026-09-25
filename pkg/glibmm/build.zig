const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});
    const sv = std.SemanticVersion.parse(version) catch unreachable;
    const major: i64 = @intCast(sv.major);
    const minor: i64 = @intCast(sv.minor);
    const micro: i64 = @intCast(sv.patch);
    const sigc = b.dependency("sigcpp", .{ .target = target, .optimize = optimize }).artifact("sigc-2.0");

    // Results of upstream's tools/conf_tests/*.cc probes; clang passes all but the Sun ones.
    const glibmm_config = b.addConfigHeader(.{ .style = .{ .meson = upstream.path("glib/glibmmconfig.h.meson") }, .include_path = "glibmmconfig.h" }, .{
        .GLIBMM_CAN_ASSIGN_NON_EXTERN_C_FUNCTIONS_TO_EXTERN_C_CALLBACKS = 1,
        .GLIBMM_CAN_USE_DYNAMIC_CAST_IN_UNUSED_TEMPLATE_WITHOUT_DEFINITION = 1,
        .GLIBMM_CAN_USE_NAMESPACES_INSIDE_EXTERNC = 1,
        .GLIBMM_CAN_USE_THREAD_LOCAL = 1,
        .GLIBMM_COMPILER_SUN_FORTE = null,
        .GLIBMM_DEBUG_REFCOUNTING = null,
        .GLIBMM_DISABLE_DEPRECATED = null,
        .GLIBMM_HAVE_ALLOWS_STATIC_INLINE_NPOS = 1,
        .GLIBMM_HAVE_C_STD_TIME_T_IS_NOT_INT32 = 1,
        .GLIBMM_HAVE_DISAMBIGUOUS_CONST_TEMPLATE_SPECIALIZATIONS = 1,
        .GLIBMM_HAVE_STD_ITERATOR_TRAITS = 1,
        .GLIBMM_HAVE_SUN_REVERSE_ITERATOR = null,
        .GLIBMM_HAVE_TEMPLATE_SEQUENCE_CTORS = 1,
        .GLIBMM_HAVE_WIDE_STREAM = 1,
        .GLIBMM_MAJOR_VERSION = major,
        .GLIBMM_MEMBER_FUNCTIONS_MEMBER_TEMPLATES = 1,
        .GLIBMM_MICRO_VERSION = micro,
        .GLIBMM_MINOR_VERSION = minor,
        .GLIBMM_OS_COCOA = null,
        .GLIBMM_SIZEOF_WCHAR_T = 4,
        .GLIBMM_STATIC_LIB = 1,
    });
    const giomm_config = b.addConfigHeader(.{ .style = .{ .meson = upstream.path("gio/giommconfig.h.meson") }, .include_path = "giommconfig.h" }, .{
        .GIOMM_DISABLE_DEPRECATED = null,
        .GIOMM_MAJOR_VERSION = major,
        .GIOMM_MICRO_VERSION = micro,
        .GIOMM_MINOR_VERSION = minor,
        .GIOMM_STATIC_LIB = 1,
    });

    const glibmm_mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true });
    glibmm_mod.addIncludePath(upstream.path("glib"));
    glibmm_mod.addIncludePath(upstream.path("untracked/glib"));
    glibmm_mod.addConfigHeader(glibmm_config);
    glibmm_mod.addCMacro("GLIBMM_BUILD", "1");
    glibmm_mod.linkLibrary(sigc);
    for ([_][]const u8{
        "glib-2.0",
        "gmodule-2.0",
        "gobject-2.0",
    }) |l| glibmm_mod.linkSystemLibrary(l, .{});
    glibmm_mod.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = try util.glob(b, upstream.path(""), .{ .include = &.{
            "glib/glibmm/*.cc",
            "untracked/glib/glibmm/*.cc",
        } }),
        .flags = &.{"-std=c++11"},
    });
    const glibmm = b.addLibrary(.{ .name = "glibmm-2.4", .root_module = glibmm_mod, .linkage = .static });
    glibmm.installHeader(upstream.path("glib/glibmm.h"), "glibmm.h");
    glibmm.installHeadersDirectory(upstream.path("glib/glibmm"), "glibmm", .{});
    glibmm.installHeadersDirectory(upstream.path("untracked/glib/glibmm"), "glibmm", .{});
    glibmm.installConfigHeader(glibmm_config);
    // As upstream's pkg-config Requires: glibmm's headers include sigc++'s.
    glibmm.installLibraryHeaders(sigc);
    b.installArtifact(glibmm);

    const giomm_mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true });
    giomm_mod.addIncludePath(upstream.path("gio"));
    giomm_mod.addIncludePath(upstream.path("untracked/gio"));
    giomm_mod.addConfigHeader(giomm_config);
    giomm_mod.addCMacro("GIOMM_BUILD", "1");
    giomm_mod.linkLibrary(glibmm);
    for ([_][]const u8{
        "gio-2.0",
        "gio-unix-2.0",
    }) |l| giomm_mod.linkSystemLibrary(l, .{});
    giomm_mod.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = try util.glob(b, upstream.path(""), .{ .include = &.{
            "gio/giomm/*.cc",
            "untracked/gio/giomm/*.cc",
        } }),
        .flags = &.{"-std=c++11"},
    });
    const giomm = b.addLibrary(.{ .name = "giomm-2.4", .root_module = giomm_mod, .linkage = .static });
    giomm.installHeader(upstream.path("gio/giomm.h"), "giomm.h");
    giomm.installHeadersDirectory(upstream.path("gio/giomm"), "giomm", .{});
    giomm.installHeadersDirectory(upstream.path("untracked/gio/giomm"), "giomm", .{});
    giomm.installConfigHeader(giomm_config);
    giomm.installLibraryHeaders(glibmm);
    b.installArtifact(giomm);
}
