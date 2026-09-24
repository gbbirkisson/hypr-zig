const std = @import("std");
const util = @import("build_util");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const upstream = b.dependency("upstream", .{});

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true, .strip = optimize != .debug });
    mod.addIncludePath(upstream.path("inc"));
    mod.addIncludePath(upstream.path("src"));
    // Upstream CMake's literal; the fork never changed it.
    mod.addCMacro("VERSION", "\"1.4.1-1\"");
    mod.addCMacro("_GNU_SOURCE", "");
    mod.linkLibrary(b.dependency("wayland", .{ .target = target, .optimize = optimize }).artifact("wayland-client"));
    for ([_][]const u8{
        "dl",
        "gio-unix-2.0",
        "gtk+-3.0",
        "m",
    }) |l| mod.linkSystemLibrary(l, .{});
    mod.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = try util.glob(b, upstream.path(""), .{ .include = &.{
            "modes/*.c",
            "proto/*.c",
            "src/*.c",
        } }),
        .flags = &.{"-std=gnu99"},
    });
    // Modes are resolved with dlsym(RTLD_DEFAULT, "wofi_<mode>_init"), so symbols must be exported.
    const exe = b.addExecutable(.{ .name = "wofi", .root_module = mod });
    exe.rdynamic = true;
    b.installArtifact(exe);

    const data = b.addWriteFiles();
    for (try util.glob(b, upstream.path(""), .{ .include = &.{
        "man/*.1",
        "man/*.3",
        "man/*.5",
        "man/*.7",
    } })) |m| {
        const section = m[m.len - 1 ..];
        _ = data.addCopyFile(upstream.path(m), b.fmt("share/man/man{s}/{s}", .{ section, std.fs.path.basename(m) }));
    }
    b.addNamedLazyPath("data", data.getDirectory());
}
