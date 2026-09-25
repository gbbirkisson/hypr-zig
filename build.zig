const std = @import("std");

const App = struct { pkg: []const u8, step: []const u8, bins: []const []const u8 };

const apps = [_]App{
    .{ .pkg = "batsignal", .step = "batsignal", .bins = &.{"batsignal"} },
    .{ .pkg = "hypridle", .step = "hypridle", .bins = &.{"hypridle"} },
    .{ .pkg = "hyprland", .step = "hyprland", .bins = &.{
        "Hyprland",
        "hyprctl",
        "start-hyprland",
    } },
    .{ .pkg = "hyprland_guiutils", .step = "hyprland-guiutils", .bins = &.{
        "hyprland-dialog",
        "hyprland-donate-screen",
        "hyprland-run",
        "hyprland-update-screen",
        "hyprland-welcome",
    } },
    .{ .pkg = "hyprlock", .step = "hyprlock", .bins = &.{"hyprlock"} },
    .{ .pkg = "hyprpaper", .step = "hyprpaper", .bins = &.{"hyprpaper"} },
    .{ .pkg = "waybar", .step = "waybar", .bins = &.{"waybar"} },
    .{ .pkg = "wofi", .step = "wofi", .bins = &.{"wofi"} },
    .{ .pkg = "xdg_desktop_portal_hyprland", .step = "xdg-desktop-portal-hyprland", .bins = &.{
        "hyprland-share-picker",
        "xdg-desktop-portal-hyprland",
    } },
};

// Libraries built by this repo; none may appear as a direct shared dependency of a binary.
const static_only = "libhypr|libaquamarine|libwayland-(server|client|egl)|libinput\\.|libxkbcommon\\.|libxkbregistry|liblua|libre2|libabsl|libmuparser|libglslang|libudis86|libpugixml|libdisplay-info|libsdbus|libdate|libsigc|libglibmm|libgiomm|libcairomm|libpangomm|libatkmm|libgdkmm|libgtkmm|libjsoncpp|libfmt\\.|libspdlog|libgtk-layer-shell|libstdc\\+\\+";

const check_script =
    \\for f; do
    \\  out=$(readelf -d "$f") || exit 1
    \\  if printf '%s\n' "$out" | grep NEEDED | grep -E "$STATIC_ONLY"; then echo "$f"; exit 1; fi
    \\done
;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.option(std.builtin.Optimize, "optimize", "Optimization mode (default: fast)") orelse .fast;

    const all = b.step("all", "Compile every app (default)");
    b.default_step = all;
    const check = b.addSystemCommand(&.{ "sh", "-c", check_script, "sh" });
    check.setEnvironmentVariable("STATIC_ONLY", static_only);

    for (apps) |app| {
        const dep = b.dependency(app.pkg, .{ .target = target, .optimize = optimize });
        const step = b.step(app.step, b.fmt("Compile {s}", .{app.step}));
        all.dependOn(step);
        for (app.bins) |name| {
            const exe = dep.artifact(name);
            step.dependOn(&exe.step);
            b.installArtifact(exe);
            check.addArtifactArg(exe);
        }
        b.installDirectory(.{ .source_dir = dep.namedLazyPath("data"), .install_dir = .prefix, .install_subdir = "" });
    }
    b.step("check", "Fail if a Zig-built library is linked dynamically").dependOn(&check.step);
}
