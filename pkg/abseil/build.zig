const std = @import("std");
const util = @import("build_util");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true });
    mod.addIncludePath(upstream.path(""));
    mod.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = try util.glob(b, upstream.path(""), .{
            .include = &.{"absl/**/*.cc"},
            .exclude = &.{
                "**/*_benchmark*.cc",
                "**/*_matchers.cc",
                "**/*_test*.cc",
                "**/*_win.cc",
                "**/*fuzz*.cc",
                "**/*mock*.cc",
                "**/benchmarks.cc",
                "**/gtest*.cc",
                "**/nanobenchmark.cc",
                "**/test_*.cc",
                // Standalone tools with their own main().
                "absl/hash/internal/print_hash_of.cc",
                "absl/random/internal/*_gentables.cc",
            },
        }),
        .flags = &.{"-std=c++23"},
    });
    const lib = b.addLibrary(.{ .name = "absl", .root_module = mod, .linkage = .static });
    lib.installHeadersDirectory(upstream.path("absl"), "absl", .{
        .include_extensions = &.{
            ".h",
            ".inc",
        },
    });
    b.installArtifact(lib);
}
