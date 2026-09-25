const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});
    const opts = .{ .target = target, .optimize = optimize };
    const sv = std.SemanticVersion.parse(version) catch unreachable;
    const major: i64 = @intCast(sv.major);
    const minor: i64 = @intCast(sv.minor);
    const micro: i64 = @intCast(sv.patch);

    const gdk_config = b.addConfigHeader(.{ .style = .{ .meson = upstream.path("gdk/gdkmmconfig.h.meson") }, .include_path = "gdkmmconfig.h" }, .{
        .GDKMM_DISABLE_DEPRECATED = null,
        .GDKMM_MAJOR_VERSION = major,
        .GDKMM_MICRO_VERSION = micro,
        .GDKMM_MINOR_VERSION = minor,
        // Meson enables it when gtk+-3.0's targets include x11, as Debian's and Ubuntu's do.
        .GDKMM_X11_BACKEND_ENABLED = 1,
    });
    const gtk_config = b.addConfigHeader(.{ .style = .{ .meson = upstream.path("gtk/gtkmmconfig.h.meson") }, .include_path = "gtkmmconfig.h" }, .{
        .GTKMM_ATKMM_ENABLED = 1,
        .GTKMM_DISABLE_DEPRECATED = null,
        .GTKMM_MAJOR_VERSION = major,
        .GTKMM_MICRO_VERSION = micro,
        .GTKMM_MINOR_VERSION = minor,
        .GTKMM_STATIC_LIB = 1,
    });

    const gdk_mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true });
    gdk_mod.addIncludePath(upstream.path("gdk"));
    gdk_mod.addIncludePath(upstream.path("untracked/gdk"));
    gdk_mod.addConfigHeader(gdk_config);
    gdk_mod.addCMacro("GDKMM_BUILD", "1");
    // As upstream's pkg-config Requires: gdkmm's headers include these.
    const gdk_public = [_]*std.Build.Step.Compile{
        b.dependency("glibmm", opts).artifact("giomm-2.4"),
        b.dependency("pangomm", opts).artifact("pangomm-1.4"),
    };
    for (gdk_public) |l| gdk_mod.linkLibrary(l);
    gdk_mod.linkSystemLibrary("gtk+-3.0", .{});
    gdk_mod.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = try util.glob(b, upstream.path(""), .{ .include = &.{
            "gdk/gdkmm/*.cc",
            "untracked/gdk/gdkmm/*.cc",
        } }),
        .flags = &.{"-std=c++11"},
    });
    const gdk = b.addLibrary(.{ .name = "gdkmm-3.0", .root_module = gdk_mod, .linkage = .static });
    gdk.installHeader(upstream.path("gdk/gdkmm.h"), "gdkmm.h");
    gdk.installHeadersDirectory(upstream.path("gdk/gdkmm"), "gdkmm", .{});
    gdk.installHeadersDirectory(upstream.path("untracked/gdk/gdkmm"), "gdkmm", .{});
    gdk.installConfigHeader(gdk_config);
    for (gdk_public) |l| gdk.installLibraryHeaders(l);
    b.installArtifact(gdk);

    const gtk_mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true });
    gtk_mod.addIncludePath(upstream.path("gtk"));
    gtk_mod.addIncludePath(upstream.path("untracked/gtk"));
    gtk_mod.addConfigHeader(gtk_config);
    gtk_mod.addCMacro("GTKMM_BUILD", "1");
    const gtk_public = [_]*std.Build.Step.Compile{
        b.dependency("atkmm", opts).artifact("atkmm-1.6"),
        gdk,
    };
    for (gtk_public) |l| gtk_mod.linkLibrary(l);
    for ([_][]const u8{
        "gtk+-3.0",
        // Print dialogs include gtk/gtkunixprint.h.
        "gtk+-unix-print-3.0",
    }) |l| gtk_mod.linkSystemLibrary(l, .{});
    gtk_mod.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = try util.glob(b, upstream.path(""), .{ .include = &.{
            "gtk/gtkmm/*.cc",
            "untracked/gtk/gtkmm/*.cc",
        } }),
        .flags = &.{"-std=c++11"},
    });
    const gtk = b.addLibrary(.{ .name = "gtkmm-3.0", .root_module = gtk_mod, .linkage = .static });
    gtk.installHeader(upstream.path("gtk/gtkmm.h"), "gtkmm.h");
    gtk.installHeadersDirectory(upstream.path("gtk/gtkmm"), "gtkmm", .{});
    gtk.installHeadersDirectory(upstream.path("untracked/gtk/gtkmm"), "gtkmm", .{});
    gtk.installConfigHeader(gtk_config);
    for (gtk_public) |l| gtk.installLibraryHeaders(l);
    b.installArtifact(gtk);
}
