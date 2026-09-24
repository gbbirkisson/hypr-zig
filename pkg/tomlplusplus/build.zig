const std = @import("std");

pub fn build(b: *std.Build) void {
    b.addNamedLazyPath("include", b.dependency("upstream", .{}).path("include"));
}
