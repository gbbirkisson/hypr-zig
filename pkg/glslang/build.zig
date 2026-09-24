const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});
    const sv = std.SemanticVersion.parse(version) catch unreachable;

    const build_info = b.addConfigHeader(.{
        .style = .{ .autoconf_at = upstream.path("build_info.h.tmpl") },
        .include_path = "glslang/build_info.h",
    }, .{
        .major = @as(i64, @intCast(sv.major)),
        .minor = @as(i64, @intCast(sv.minor)),
        .patch = @as(i64, @intCast(sv.patch)),
        .flavor = "",
    });
    const flags: []const []const u8 = &.{
        "-fno-exceptions",
        "-fno-rtti",
        "-std=c++17",
    };

    const libs = [_]struct { name: []const u8, srcs: []const []const u8 }{
        .{ .name = "glslang", .srcs = try util.glob(b, upstream.path(""), .{
            .include = &.{
                "SPIRV/**/*.cpp",
                "glslang/**/*.cpp",
            },
            .exclude = &.{
                "**/stub.cpp",
                "glslang/HLSL/**",
                "glslang/OSDependent/Web/**",
                "glslang/OSDependent/Windows/**",
                "glslang/ResourceLimits/**",
            },
        }) },
        .{ .name = "glslang-default-resource-limits", .srcs = try util.glob(b, upstream.path(""), .{ .include = &.{"glslang/ResourceLimits/*.cpp"} }) },
    };
    for (libs) |l| {
        const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true });
        mod.addIncludePath(upstream.path(""));
        mod.addConfigHeader(build_info);
        mod.addCMacro("ENABLE_SPIRV", "1");
        mod.addCMacro("ENABLE_OPT", "0");
        mod.addCMacro("GLSLANG_OSINCLUDE_UNIX", "");
        mod.addCSourceFiles(.{ .root = upstream.path(""), .files = l.srcs, .flags = flags });
        const lib = b.addLibrary(.{ .name = l.name, .root_module = mod, .linkage = .static });
        lib.installHeadersDirectory(upstream.path("glslang/Include"), "glslang/Include", .{});
        lib.installHeadersDirectory(upstream.path("glslang/Public"), "glslang/Public", .{});
        lib.installConfigHeader(build_info);
        b.installArtifact(lib);
    }
}
