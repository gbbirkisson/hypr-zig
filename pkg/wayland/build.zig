const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

/// libwayland-server and libwayland-client define the core protocol's interface symbols.
pub const protocols = [_]util.Protocol{
    .{ .name = "wayland", .side = .interfaces },
};

const flags = [_][]const u8{
    "-D_POSIX_C_SOURCE=200809L",
    "-Wno-unused-parameter",
    "-fvisibility=hidden",
    "-std=c99",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});
    const sv = std.SemanticVersion.parse(version) catch unreachable;

    // `connection.c` and `wayland-os.c` include "../config.h", so config.h also lives one level up.
    const config = b.addConfigHeader(.{ .include_path = "config.h" }, .{
        .PACKAGE = "wayland",
        .PACKAGE_VERSION = version,
        .HAVE_SYS_PRCTL_H = 1,
        .HAVE_ACCEPT4 = 1,
        .HAVE_MKOSTEMP = 1,
        .HAVE_POSIX_FALLOCATE = 1,
        .HAVE_PRCTL = 1,
        .HAVE_MEMFD_CREATE = 1,
        .HAVE_MREMAP = 1,
        .HAVE_STRNDUP = 1,
        .HAVE_GETTID = 1,
        .HAVE_XUCRED_CR_PID = 0,
        .HAVE_BROKEN_MSG_CMSG_CLOEXEC = 0,
    });
    const config_tree = b.addWriteFiles();
    _ = config_tree.addCopyFile(config.getOutputFile(), "config.h");
    _ = config_tree.addCopyFile(config.getOutputFile(), "sub/config.h");

    const version_h = b.addConfigHeader(.{
        .style = .{ .cmake = upstream.path("src/wayland-version.h.in") },
        .include_path = "wayland-version.h",
    }, .{
        .WAYLAND_VERSION = version,
        .WAYLAND_VERSION_MAJOR = @as(i64, @intCast(sv.major)),
        .WAYLAND_VERSION_MINOR = @as(i64, @intCast(sv.minor)),
        .WAYLAND_VERSION_MICRO = @as(i64, @intCast(sv.patch)),
    });

    const scanner = b.addExecutable(.{
        .name = "wayland-scanner",
        .root_module = b.createModule(.{ .target = b.graph.host, .optimize = .ReleaseFast, .link_libc = true }),
    });
    scanner.root_module.addIncludePath(upstream.path("src"));
    scanner.root_module.addConfigHeader(version_h);
    // Upstream force-includes config.h; the scanner only reads HAVE_STRNDUP from it.
    scanner.root_module.addCMacro("HAVE_STRNDUP", "1");
    scanner.root_module.addCSourceFiles(.{ .root = upstream.path("src"), .files = &.{
        "scanner.c",
        "wayland-util.c",
    }, .flags = &flags });
    scanner.root_module.linkSystemLibrary("expat", .{});
    b.installArtifact(scanner);

    const xml = upstream.path("protocol/wayland.xml");
    b.addNamedLazyPath("wayland-xml", xml);

    const gen = b.addWriteFiles();
    for ([_][2][]const u8{
        .{ "client-header", "wayland-client-protocol.h" },
        .{ "public-code", "wayland-protocol.c" },
        .{ "server-header", "wayland-server-protocol.h" },
    }) |m| {
        const run = b.addRunArtifact(scanner);
        run.addArgs(&.{ "-s", m[0] });
        run.addFileArg(xml);
        _ = gen.addCopyFile(run.addOutputFileArg(m[1]), m[1]);
    }

    for ([_]struct { name: []const u8, srcs: []const []const u8, headers: []const []const u8 }{
        .{
            .name = "wayland-client",
            .srcs = &.{"wayland-client.c"},
            .headers = &.{
                "wayland-client-core.h",
                "wayland-client.h",
            },
        },
        .{
            .name = "wayland-server",
            .srcs = &.{
                "event-loop.c",
                "wayland-server.c",
                "wayland-shm.c",
            },
            .headers = &.{
                "wayland-server-core.h",
                "wayland-server.h",
            },
        },
    }) |l| {
        const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true });
        mod.addIncludePath(upstream.path("src"));
        mod.addIncludePath(config_tree.getDirectory());
        mod.addIncludePath(config_tree.getDirectory().path(b, "sub"));
        mod.addIncludePath(gen.getDirectory());
        mod.addConfigHeader(version_h);
        mod.addCSourceFiles(.{ .root = upstream.path("src"), .files = l.srcs, .flags = &flags });
        mod.addCSourceFiles(.{ .root = upstream.path("src"), .files = &.{
            "connection.c",
            "wayland-os.c",
            "wayland-util.c",
        }, .flags = &flags });
        mod.addCSourceFiles(.{ .root = gen.getDirectory(), .files = &.{"wayland-protocol.c"}, .flags = &flags });
        mod.linkSystemLibrary("libffi", .{});
        mod.linkSystemLibrary("m", .{});

        const lib = b.addLibrary(.{ .name = l.name, .root_module = mod, .linkage = .static });
        for (l.headers) |h| lib.installHeader(upstream.path(b.fmt("src/{s}", .{h})), h);
        lib.installHeader(upstream.path("src/wayland-util.h"), "wayland-util.h");
        lib.installConfigHeader(version_h);
        const proto_h = if (std.mem.eql(u8, l.name, "wayland-server")) "wayland-server-protocol.h" else "wayland-client-protocol.h";
        lib.installHeader(gen.getDirectory().path(b, proto_h), proto_h);
        b.installArtifact(lib);
    }

    const egl_mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true });
    egl_mod.addIncludePath(upstream.path("src"));
    egl_mod.addIncludePath(upstream.path("egl"));
    egl_mod.addCSourceFiles(.{ .root = upstream.path("egl"), .files = &.{"wayland-egl.c"}, .flags = &flags });
    const egl = b.addLibrary(.{ .name = "wayland-egl", .root_module = egl_mod, .linkage = .static });
    for ([_][]const u8{
        "wayland-egl-backend.h",
        "wayland-egl-core.h",
        "wayland-egl.h",
    }) |h| egl.installHeader(upstream.path(b.fmt("egl/{s}", .{h})), h);
    b.installArtifact(egl);
}
