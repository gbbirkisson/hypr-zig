const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});

    const itab = b.addSystemCommand(&.{"python3"});
    itab.addFileArg(upstream.path("scripts/ud_itab.py"));
    itab.addFileArg(upstream.path("docs/x86/optable.xml"));
    const gen = itab.addOutputDirectoryArg("itab");

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true });
    mod.addIncludePath(upstream.path(""));
    mod.addIncludePath(upstream.path("libudis86"));
    mod.addIncludePath(gen);
    const flags: []const []const u8 = &.{"-std=c99"};
    mod.addCSourceFiles(.{
        .root = upstream.path("libudis86"),
        .files = &.{
            "decode.c",
            "syn-att.c",
            "syn-intel.c",
            "syn.c",
            "udis86.c",
        },
        .flags = flags,
    });
    mod.addCSourceFile(.{ .file = gen.path(b, "itab.c"), .flags = flags });

    const lib = b.addLibrary(.{ .name = "udis86", .root_module = mod, .linkage = .static });
    lib.installHeader(upstream.path("udis86.h"), "udis86.h");
    lib.installHeadersDirectory(upstream.path("libudis86"), "libudis86", .{});
    lib.installHeader(gen.path(b, "itab.h"), "libudis86/itab.h");
    b.installArtifact(lib);
}
