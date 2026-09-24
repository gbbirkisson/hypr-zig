const std = @import("std");
const util = @import("build_util");
const manifest = @import("build.zig.zon");

pub const version = util.versionFromUrl(manifest.dependencies.upstream.url);

pub fn build(b: *std.Build) void {
    b.addNamedLazyPath("root", b.dependency("upstream", .{}).path(""));
}
