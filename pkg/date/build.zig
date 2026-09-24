const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true });
    mod.addIncludePath(upstream.path("include"));
    for ([_][2][]const u8{
        .{ "AUTO_DOWNLOAD", "0" },
        .{ "BUILD_TZ_LIB", "1" },
        .{ "HAS_REMOTE_API", "0" },
        .{ "INSTALL", "." },
        .{ "USE_OS_TZDB", "1" },
    }) |m| mod.addCMacro(m[0], m[1]);
    mod.addCSourceFiles(.{ .root = upstream.path(""), .files = &.{"src/tz.cpp"}, .flags = &.{"-std=c++17"} });
    const lib = b.addLibrary(.{ .name = "date-tz", .root_module = mod, .linkage = .static });
    lib.installHeadersDirectory(upstream.path("include/date"), "date", .{});
    b.installArtifact(lib);
}
