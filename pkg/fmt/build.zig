const std = @import("std");
const util = @import("build_util");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true });
    mod.addIncludePath(upstream.path("include"));
    mod.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = try util.glob(b, upstream.path(""), .{
            .include = &.{"src/*.cc"},
            // C++20 module interface and the separate C API library.
            .exclude = &.{
                "src/fmt-c.cc",
                "src/fmt.cc",
            },
        }),
        .flags = &.{"-std=c++20"},
    });
    const lib = b.addLibrary(.{ .name = "fmt", .root_module = mod, .linkage = .static });
    lib.installHeadersDirectory(upstream.path("include/fmt"), "fmt", .{});
    b.installArtifact(lib);
}
