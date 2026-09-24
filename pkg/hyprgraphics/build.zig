const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true });
    mod.addIncludePath(upstream.path("include"));
    mod.addIncludePath(upstream.path("src"));
    mod.addCMacro("HYPRGRAPHICS_VERSION", b.fmt("\"{s}\"", .{version}));
    mod.addCMacro("__cpp_concepts", "202002L");
    mod.linkLibrary(b.dependency("hyprutils", .{ .target = target, .optimize = optimize }).artifact("hyprutils"));
    for ([_][]const u8{
        "cairo",
        "egl",
        "glesv2",
        "libdrm",
        "libjpeg",
        "libmagic",
        "libpng",
        "librsvg-2.0",
        "libwebp",
        "pangocairo",
        "pixman-1",
    }) |l|
        mod.linkSystemLibrary(l, .{});
    mod.addCSourceFiles(.{
        .root = upstream.path(""),
        // JXL and AVIF are optional upstream and not built.
        .files = try util.glob(b, upstream.path(""), .{
            .include = &.{"src/**/*.cpp"},
            .exclude = &.{
                "**/Avif.cpp",
                "**/JpegXL.cpp",
            },
        }),
        .flags = &.{
            "-Wno-missing-braces",
            "-Wno-unused-parameter",
            "-std=c++26",
        },
    });
    const lib = b.addLibrary(.{ .name = "hyprgraphics", .root_module = mod, .linkage = .static });
    lib.installHeadersDirectory(upstream.path("include"), "", .{ .include_extensions = null });
    b.installArtifact(lib);
}
