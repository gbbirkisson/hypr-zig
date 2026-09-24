const std = @import("std");
const util = @import("build_util");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true });
    mod.addIncludePath(upstream.path("include"));
    mod.addIncludePath(upstream.path("src"));
    for ([_][2][]const u8{
        .{ "BUILD_LIB", "1" },
        // Gates code for systemd 240 to 246; 255 is Ubuntu 24.04, older than Debian trixie's.
        .{ "LIBSYSTEMD_VERSION", "255" },
        .{ "SDBUS_HEADER", "<systemd/sd-bus.h>" },
        .{ "SDBUS_systemd", "" },
    }) |m| mod.addCMacro(m[0], m[1]);
    mod.linkSystemLibrary("libsystemd", .{});
    mod.addCSourceFiles(.{ .root = upstream.path(""), .files = try util.glob(b, upstream.path(""), .{ .include = &.{"src/*.cpp"} }), .flags = &.{"-std=c++20"} });
    mod.addCSourceFiles(.{ .root = upstream.path(""), .files = try util.glob(b, upstream.path(""), .{ .include = &.{"src/*.c"} }), .flags = &.{"-std=c11"} });
    const lib = b.addLibrary(.{ .name = "sdbus-c++", .root_module = mod, .linkage = .static });
    lib.installHeadersDirectory(upstream.path("include/sdbus-c++"), "sdbus-c++", .{ .include_extensions = null });
    b.installArtifact(lib);
}
