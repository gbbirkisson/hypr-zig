const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});
    const opts = .{ .target = target, .optimize = optimize };

    // Upstream also generates eight Wayland protocols that no source uses; they would duplicate
    // hyprtoolkit's and aquamarine's.
    const hw_gen = b.addWriteFiles();
    const server = util.hyprwireProtocol(b, b.dependency("hyprwire", .{}).artifact("hyprwire-scanner"), hw_gen, upstream.path("hw-protocols/hyprpaper_core.xml"), "hyprpaper_core", .server);

    const flags: []const []const u8 = &.{
        "-Wno-missing-field-initializers",
        "-Wno-narrowing",
        "-Wno-unused-parameter",
        "-Wno-unused-value",
        "-std=c++23",
    };
    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libcpp = true, .strip = optimize != .debug });
    mod.addIncludePath(upstream.path(""));
    mod.addIncludePath(upstream.path("src"));
    mod.addIncludePath(hw_gen.getDirectory());
    mod.addCMacro("HYPRPAPER_VERSION", b.fmt("\"{s}\"", .{version}));
    for ([_][2][]const u8{
        .{ "hyprlang", "hyprlang" },
        .{ "hyprtoolkit", "hyprtoolkit" },
        .{ "hyprutils", "hyprutils" },
        .{ "hyprwire", "hyprwire" },
    }) |d| mod.linkLibrary(b.dependency(d[0], opts).artifact(d[1]));
    mod.linkSystemLibrary("libmagic", .{});
    mod.addCSourceFiles(.{ .root = upstream.path(""), .files = try util.glob(b, upstream.path(""), .{ .include = &.{"src/**/*.cpp"} }), .flags = flags });
    mod.addCSourceFiles(.{ .root = hw_gen.getDirectory(), .files = &.{server}, .flags = flags });
    const exe = b.addExecutable(.{ .name = "hyprpaper", .root_module = mod });
    exe.rdynamic = true;
    b.installArtifact(exe);

    const unit = b.addSystemCommand(&.{ "sed", "s|@CMAKE_INSTALL_PREFIX@/bin/||" });
    unit.addFileArg(upstream.path("systemd/hyprpaper.service.in"));
    const data = b.addWriteFiles();
    _ = data.addCopyFile(unit.captureStdOut(.{}), "lib/systemd/user/hyprpaper.service");
    b.addNamedLazyPath("data", data.getDirectory());
}
