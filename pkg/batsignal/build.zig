const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true, .strip = optimize != .debug });
    mod.linkSystemLibrary("libnotify", .{});
    mod.linkSystemLibrary("m", .{});
    // Upstream's -Werror is dropped: clang warns where upstream's GCC does not.
    mod.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = try util.glob(b, upstream.path(""), .{ .include = &.{"*.c"} }),
        .flags = &.{
            "-Wno-unused-parameter",
            "-pedantic",
        },
    });
    const exe = b.addExecutable(.{ .name = "batsignal", .root_module = mod });
    exe.rdynamic = true;
    b.installArtifact(exe);

    // Same substitutions, in the same order, as upstream's Makefile.
    const man = b.addSystemCommand(&.{
        "sed",
        "-e",
        b.fmt("s/VERSION/{s}/g", .{version}),
        "-e",
        "s/PROGNAME/batsignal/g",
        "-e",
        "s/PROGUPPER/BATSIGNAL/g",
    });
    man.addFileArg(upstream.path("batsignal.1.in"));
    const data = b.addWriteFiles();
    _ = data.addCopyFile(man.captureStdOut(.{}), "share/man/man1/batsignal.1");
    b.addNamedLazyPath("data", data.getDirectory());
}
