const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});
    const flags: []const []const u8 = &.{
        "-Wno-missing-field-initializers",
        "-Wno-unused-parameter",
        "-Wno-unused-value",
        "-std=c++23",
    };

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true });
    mod.addIncludePath(upstream.path("include"));
    mod.addIncludePath(upstream.path("src"));
    mod.addCMacro("HYPRWIRE_VERSION", b.fmt("\"{s}\"", .{version}));
    mod.linkLibrary(b.dependency("hyprutils", .{ .target = target, .optimize = optimize }).artifact("hyprutils"));
    mod.linkSystemLibrary("libffi", .{});
    mod.addCSourceFiles(.{ .root = upstream.path(""), .files = try util.glob(b, upstream.path(""), .{ .include = &.{"src/**/*.cpp"} }), .flags = flags });
    const lib = b.addLibrary(.{ .name = "hyprwire", .root_module = mod, .linkage = .static });
    lib.installHeadersDirectory(upstream.path("include"), "", .{ .include_extensions = null });
    b.installArtifact(lib);

    const smod = b.createModule(.{ .target = b.graph.host, .optimize = .fast, .link_libcpp = true });
    smod.addIncludePath(upstream.path("include"));
    smod.addCMacro("SCANNER_VERSION", b.fmt("\"{s}\"", .{version}));
    smod.linkLibrary(b.dependency("pugixml", .{ .target = b.graph.host, .optimize = .fast }).artifact("pugixml"));
    smod.addCSourceFiles(.{ .root = upstream.path(""), .files = &.{"scanner/main.cpp"}, .flags = flags });
    b.installArtifact(b.addExecutable(.{ .name = "hyprwire-scanner", .root_module = smod }));
}
