const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true });
    mod.addCMacro("LUA_USE_LINUX", "");
    mod.linkSystemLibrary("m", .{});
    mod.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = try util.glob(b, upstream.path(""), .{ .include = &.{"src/*.c"}, .exclude = &.{
            "src/lua.c",
            "src/luac.c",
        } }),
        .flags = &.{"-std=gnu99"},
    });
    const lib = b.addLibrary(.{ .name = "lua", .root_module = mod, .linkage = .static });
    for ([_][]const u8{
        "lauxlib.h",
        "lua.h",
        "lua.hpp",
        "luaconf.h",
        "lualib.h",
    }) |h|
        lib.installHeader(upstream.path(b.fmt("src/{s}", .{h})), h);
    b.installArtifact(lib);
}
