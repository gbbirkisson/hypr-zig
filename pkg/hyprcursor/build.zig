const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});
    const opts = .{ .target = target, .optimize = optimize };

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true });
    mod.addIncludePath(upstream.path("include"));
    mod.addIncludePath(upstream.path("libhyprcursor"));
    mod.addIncludePath(b.dependency("tomlplusplus", .{}).namedLazyPath("include"));
    mod.addCMacro("HYPRCURSOR_VERSION", b.fmt("\"{s}\"", .{version}));
    mod.linkLibrary(b.dependency("hyprlang", opts).artifact("hyprlang"));
    mod.linkLibrary(b.dependency("hyprutils", opts).artifact("hyprutils"));
    for ([_][]const u8{
        "cairo",
        "librsvg-2.0",
        "libzip",
    }) |l| mod.linkSystemLibrary(l, .{});
    mod.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = try util.glob(b, upstream.path(""), .{ .include = &.{"libhyprcursor/**/*.cpp"} }),
        .flags = &.{
            "-Wno-narrowing",
            "-Wno-pointer-arith",
            "-Wno-unused-parameter",
            "-std=c++23",
        },
    });
    const lib = b.addLibrary(.{ .name = "hyprcursor", .root_module = mod, .linkage = .static });
    lib.installHeadersDirectory(upstream.path("include"), "", .{ .include_extensions = null });
    b.installArtifact(lib);
}
