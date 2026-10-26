<h1>
  <p align="center">
    <img src="img-hypr.svg" alt="Logo" height="96">
    <br>+<br>
    <img src="img-zig.svg" alt="Logo" height="78">
  </p>
</h1>

<p align="center">
Build Hyprland ecosystem with the Zig build system
</p>

<!-- vim-markdown-toc GFM -->

* [Requirements](#requirements)
* [Build](#build)
* [Install](#install)
  * [All](#all)
  * [Single](#single)
* [Debug build](#debug-build)
* [Dark mode (GTK)](#dark-mode-gtk)

<!-- vim-markdown-toc -->

## Requirements

Installs build tools (pinned in `.tool-versions`) with `mise` and libraries with `apt`.

```
make deps
```

Nice to have apps when running Hyprland:

```
# Opinionated list of nice-to-haves
sudo apt install \
  brightnessctl \
  easyeffects \
  grim \
  gsimplecal \
  network-manager-gnome \
  pavucontrol \
  playerctl \
  slurp \
  sway-notification-center \
  wl-clipboard \
  xdg-desktop-portal \
  xdg-desktop-portal-gtk \
  xwayland
```

## Build

```
zig build           # compile
zig build check     # assert no Zig-built library is linked dynamically
```

## Install

### All

Builds, then copies `zig-out` into `PREFIX` (default `/usr/local`) and system paths with `sudo`.

```
make install
```

> Hyprland only finds its data under `/usr/share` or `/usr/local/share`.

### Single

Build and install single app, e.g. waybar (steps: `zig build -l`):

```
zig build waybar
sudo install -Dm755 -t /usr/local/bin zig-out/bin/waybar
```

## Debug build

Build and install one app with debug mode and symbols:

```
zig build waybar -Doptimize=Debug -p zig-out-debug
sudo install -Dm755 -t /usr/local/bin zig-out-debug/bin/waybar
```

`zig build -l` lists the app steps.

## Dark mode (GTK)

```
make dark
```
