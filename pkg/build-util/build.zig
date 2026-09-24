const std = @import("std");

pub fn build(b: *std.Build) void {
    const t = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("build.zig"),
        .target = b.graph.host,
    }) });
    b.step("test", "Test build helpers").dependOn(&b.addRunArtifact(t).step);
}

pub fn versionFromUrl(url: []const u8) []const u8 {
    var stem: []const u8 = url[0 .. url.len - ".tar.gz".len];
    if (std.mem.endsWith(u8, stem, "/archive")) stem = stem[0 .. stem.len - "/archive".len];
    var i = stem.len;
    while (i > 0 and (std.ascii.isDigit(stem[i - 1]) or stem[i - 1] == '.')) i -= 1;
    return stem[i..];
}

pub const GlobOptions = struct {
    /// Patterns relative to the dependency root. `*` matches within a path segment, `**` any number
    /// of segments.
    include: []const []const u8,
    exclude: []const []const u8 = &.{},
};

/// Sorted paths relative to `root`, a fetched source tree, matching any include and no exclude
/// pattern.
pub fn glob(b: *std.Build, root: std.Build.LazyPath, opts: GlobOptions) ![]const []const u8 {
    const io = b.graph.io;
    const base_dir, const base = switch (root) {
        .dependency => |d| .{ d.dependency.builder.root.root_dir.handle, d.sub_path },
        .src_path => |p| .{ p.owner.root.root_dir.handle, p.sub_path },
        else => @panic("glob root must be a source or dependency path"),
    };
    var list: std.ArrayList([]const u8) = .empty;
    for (opts.include) |pattern| {
        // Walk only the literal directory prefix of the pattern.
        var prefix: []const u8 = "";
        var it = std.mem.splitScalar(u8, pattern, '/');
        while (it.next()) |seg| {
            if (it.peek() == null or std.mem.indexOfScalar(u8, seg, '*') != null) break;
            prefix = pattern[0 .. @intFromPtr(seg.ptr) - @intFromPtr(pattern.ptr) + seg.len];
        }
        b.dependOnDirectoryContents(root.path(b, prefix));
        const walk_root = b.pathJoin(&.{ base, prefix });
        var d = try base_dir.openDir(io, if (walk_root.len == 0) "." else walk_root, .{ .iterate = true });
        defer d.close(io);
        var walker = try d.walk(b.allocator);
        defer walker.deinit();
        outer: while (try walker.next(io)) |e| {
            if (e.kind != .file) continue;
            const p = if (prefix.len == 0) b.dupe(e.path) else b.pathJoin(&.{ prefix, e.path });
            if (!match(pattern, p)) continue;
            for (opts.exclude) |x| if (match(x, p)) continue :outer;
            for (list.items) |q| if (std.mem.eql(u8, q, p)) continue :outer;
            try list.append(b.allocator, p);
        }
    }
    std.mem.sort([]const u8, list.items, {}, struct {
        fn lt(_: void, a: []const u8, c: []const u8) bool {
            return std.mem.lessThan(u8, a, c);
        }
    }.lt);
    return list.items;
}

pub fn match(pattern: []const u8, path: []const u8) bool {
    var p = std.mem.splitScalar(u8, pattern, '/');
    var s = std.mem.splitScalar(u8, path, '/');
    return matchSegments(&p, &s);
}

fn matchSegments(p: *std.mem.SplitIterator(u8, .scalar), s: *std.mem.SplitIterator(u8, .scalar)) bool {
    const pseg = p.next() orelse return s.next() == null;
    if (std.mem.eql(u8, pseg, "**")) {
        while (true) {
            var p2 = p.*;
            var s2 = s.*;
            if (matchSegments(&p2, &s2)) return true;
            _ = s.next() orelse return false;
        }
    }
    const sseg = s.next() orelse return false;
    return matchSegment(pseg, sseg) and matchSegments(p, s);
}

fn matchSegment(pattern: []const u8, name: []const u8) bool {
    if (pattern.len == 0) return name.len == 0;
    if (pattern[0] == '*') {
        var i: usize = 0;
        while (i <= name.len) : (i += 1) if (matchSegment(pattern[1..], name[i..])) return true;
        return false;
    }
    return name.len > 0 and pattern[0] == name[0] and matchSegment(pattern[1..], name[1..]);
}

/// `interfaces`: a C library (libwayland) that defines only the protocol's interface symbols.
pub const Side = enum { client, interfaces, server };
pub const Protocol = struct { name: []const u8, side: Side };
const Mode = enum { compile, header_only, no_interfaces };

/// How to generate a protocol that statically linked dependencies may already contain: the same side
/// is identical code, anything else shares only the interface symbols.
fn protocolMode(name: []const u8, side: Side, provided: []const Protocol) Mode {
    var mode: Mode = .compile;
    for (provided) |p| if (std.mem.eql(u8, p.name, name)) {
        if (p.side == side) return .header_only;
        mode = .no_interfaces;
    };
    return mode;
}

pub const ProtocolOptions = struct {
    side: Side,
    flags: []const []const u8 = &.{},
    provided: []const Protocol = &.{},
};

/// Runs hyprwayland-scanner and copies its output to `gen` under `protocols/`. Returns the .cpp to
/// compile, or null when a dependency already provides it.
pub fn hyprwaylandProtocol(
    b: *std.Build,
    scanner: *std.Build.Step.Compile,
    gen: *std.Build.Step.WriteFile,
    xml: std.Build.LazyPath,
    name: []const u8,
    opts: ProtocolOptions,
) ?[]const u8 {
    const mode = protocolMode(name, opts.side, opts.provided);
    const run = b.addRunArtifact(scanner);
    run.addArgs(opts.flags);
    if (opts.side == .client) run.addArg("--client");
    if (mode == .no_interfaces) run.addArg("--no-interfaces");
    run.addFileArg(xml);
    const out = run.addOutputDirectoryArg(name);
    const hpp = b.fmt("{s}.hpp", .{name});
    _ = gen.addCopyFile(out.path(b, hpp), b.fmt("protocols/{s}", .{hpp}));
    if (mode == .header_only) return null;
    const cpp = b.fmt("{s}.cpp", .{name});
    _ = gen.addCopyFile(out.path(b, cpp), b.fmt("protocols/{s}", .{cpp}));
    return b.fmt("protocols/{s}", .{cpp});
}

/// Runs hyprwire-scanner. `name` is the XML's <protocol name>; outputs land flat in `gen`. Returns the
/// .cpp to compile.
pub fn hyprwireProtocol(
    b: *std.Build,
    scanner: *std.Build.Step.Compile,
    gen: *std.Build.Step.WriteFile,
    xml: std.Build.LazyPath,
    name: []const u8,
    side: Side,
) []const u8 {
    const run = b.addRunArtifact(scanner);
    if (side == .client) run.addArg("--client");
    run.addFileArg(xml);
    const out = run.addOutputDirectoryArg(name);
    const s = @tagName(side);
    for ([_][]const u8{
        b.fmt("{s}-spec.hpp", .{name}),
        b.fmt("{s}-{s}.cpp", .{ name, s }),
        b.fmt("{s}-{s}.hpp", .{ name, s }),
    }) |f| _ = gen.addCopyFile(out.path(b, f), f);
    return b.fmt("{s}-{s}.cpp", .{ name, s });
}

/// Copy of `root` with every patch applied (`patch -p1`).
pub fn patched(b: *std.Build, root: std.Build.LazyPath, patches: []const std.Build.LazyPath) std.Build.LazyPath {
    const run = b.addSystemCommand(&.{
        "sh", "-c",
        \\set -e
        \\src=$1; out=$2; shift 2
        \\cp -R "$src"/. "$out"
        \\chmod -R u+w "$out"
        \\for p; do
        \\  log=$(patch -d "$out" -p1 --force --fuzz=0 --no-backup-if-mismatch < "$p") || { printf '%s\n' "$log" >&2; exit 1; }
        \\done
        ,
        "sh",
    });
    run.addDirectoryArg(root);
    const out = run.addOutputDirectoryArg("src");
    for (patches) |p| run.addFileArg(p);
    return out;
}

test versionFromUrl {
    try std.testing.expectEqualStrings("0.56.2", versionFromUrl("https://github.com/hyprwm/Hyprland/archive/refs/tags/v0.56.2.tar.gz"));
    try std.testing.expectEqualStrings("1.11.0", versionFromUrl("https://github.com/xkbcommon/libxkbcommon/archive/refs/tags/xkbcommon-1.11.0.tar.gz"));
    try std.testing.expectEqualStrings("1.26.0", versionFromUrl("https://gitlab.freedesktop.org/wayland/wayland/-/archive/1.26.0/archive.tar.gz"));
    try std.testing.expectEqualStrings("5.5.0", versionFromUrl("https://www.lua.org/ftp/lua-5.5.0.tar.gz"));
    try std.testing.expectEqualStrings("16.6.0", versionFromUrl("https://github.com/KhronosGroup/glslang/archive/refs/tags/16.6.0.tar.gz"));
}

test match {
    try std.testing.expect(match("absl/**/*.cc", "absl/base/casts.cc"));
    try std.testing.expect(match("absl/**/*.cc", "absl/casts.cc"));
    try std.testing.expect(!match("absl/**/*.cc", "absl/base/casts.h"));
    try std.testing.expect(match("**/*_test.cc", "absl/strings/str_cat_test.cc"));
    try std.testing.expect(!match("**/*_test.cc", "absl/strings/latest_test_util.cc"));
    try std.testing.expect(match("**/test_*.cc", "absl/log/internal/test_actions.cc"));
    try std.testing.expect(match("glslang/HLSL/**", "glslang/HLSL/hlslGrammar.cpp"));
    try std.testing.expect(!match("glslang/HLSL/**", "glslang/MachineIndependent/Scan.cpp"));
    try std.testing.expect(match("src/*.c", "src/lua.c"));
    try std.testing.expect(!match("src/*.c", "src/x11/keymap.c"));
    try std.testing.expect(match("**/*mock*.cc", "absl/random/mocking_bit_gen.cc"));
}

test protocolMode {
    const provided = [_]Protocol{
        .{ .name = "wayland", .side = .client },
        .{ .name = "xdg-shell", .side = .client },
    };
    try std.testing.expectEqual(Mode.compile, protocolMode("viewporter", .client, &provided));
    try std.testing.expectEqual(Mode.header_only, protocolMode("xdg-shell", .client, &provided));
    try std.testing.expectEqual(Mode.no_interfaces, protocolMode("wayland", .server, &provided));
    const libwayland = [_]Protocol{.{ .name = "wayland", .side = .interfaces }};
    try std.testing.expectEqual(Mode.no_interfaces, protocolMode("wayland", .client, &libwayland));
}
