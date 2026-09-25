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

<!-- vim-markdown-toc -->

## Requirements

Build tools (Zig, bison, binutils, patch, Python, xmllint) are pinned in `.tool-versions`.

```
# Install build tools
mise install

# Install dependencies

# Build tools and data: pkg-config, aquamarine (hwdata), libinput (quirks), libxkbcommon (keymaps)
sudo apt install \
  hwdata \
  libinput-bin \
  pkg-config \
  xkb-data

# Graphics: aquamarine, hyprgraphics, hyprland, hyprlock, hyprtoolkit
sudo apt install \
  libdrm-dev \
  libegl-dev \
  libgbm-dev \
  libgles-dev \
  libpixman-1-dev

# Drawing and text: cairomm, hyprcursor, hyprgraphics, hyprland, hyprlock, hyprtoolkit, pangomm
sudo apt install \
  libcairo2-dev \
  libpango1.0-dev

# Images: hyprcursor, hyprgraphics, hyprpaper
sudo apt install \
  libjpeg-dev \
  libmagic-dev \
  libpng-dev \
  librsvg2-dev \
  libwebp-dev \
  libzip-dev

# Input: aquamarine, libinput, waybar
sudo apt install \
  libevdev-dev \
  libmtdev-dev \
  libseat-dev \
  libudev-dev

# Wayland: wayland, hyprwire
sudo apt install \
  libexpat1-dev \
  libffi-dev

# GLib (and gdbus-codegen, glib-compile-resources): glibmm, hyprland, waybar, wofi
sudo apt install \
  libglib2.0-dev

# GTK (and gtk+-unix-print-3.0): gtk-layer-shell, gtkmm, waybar, wofi
sudo apt install \
  libgtk-3-dev

# sdbus-cpp: hypridle, hyprlock, xdg-desktop-portal-hyprland
sudo apt install \
  libsystemd-dev

# uuid: hyprland, xdg-desktop-portal-hyprland
sudo apt install \
  uuid-dev

# atkmm
sudo apt install \
  libatk1.0-dev

# batsignal
sudo apt install \
  libnotify-dev

# gtkmm
sudo apt install \
  libepoxy-dev \
  libgdk-pixbuf-2.0-dev

# hyprland
sudo apt install \
  libeis-dev \
  liblcms2-dev \
  libreadline-dev \
  libxcursor-dev

# hyprlock
sudo apt install \
  libpam0g-dev

# hyprtoolkit
sudo apt install \
  libiniparser-dev

# libxkbcommon (xkbregistry)
sudo apt install \
  libxml2-dev

# waybar
sudo apt install \
  libdbusmenu-gtk3-dev \
  libpulse-dev

# xdg-desktop-portal-hyprland
sudo apt install \
  libpipewire-0.3-dev \
  libspa-0.2-dev
```

Nice to have apps when running Hyprland.

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
  xdg-desktop-portal-gtk
```

## Build

```
zig build           # compile
zig build check     # assert no Zig-built library is linked dynamically
```

## Install

```
zig build install
```

Then copy the tree into place, by type:

```
# Binaries
sudo install -Dm755 -t /usr/local/bin zig-out/bin/*

# PAM (hyprlock)
sudo install -Dm644 -t /etc/pam.d zig-out/etc/pam.d/*

# systemd user units
sudo install -Dm644 -t /usr/local/lib/systemd/user zig-out/lib/systemd/user/*

# D-Bus and portals; xdg-desktop-portal only reads .portal files from /usr/share
sudo install -Dm644 -t /usr/local/share/dbus-1/services zig-out/share/dbus-1/services/*
sudo install -Dm644 -t /usr/local/share/xdg-desktop-portal zig-out/share/xdg-desktop-portal/*.conf
sudo install -Dm644 -t /usr/share/xdg-desktop-portal/portals zig-out/share/xdg-desktop-portal/portals/*

# Sessions
sudo install -Dm644 -t /usr/local/share/wayland-sessions zig-out/share/wayland-sessions/*

# Hyprland data: example configs, wallpapers, Lua stubs
sudo install -Dm644 -t /usr/local/share/hypr $(find zig-out/share/hypr -maxdepth 1 -type f)
sudo install -Dm644 -t /usr/local/share/hypr/stubs zig-out/share/hypr/stubs/*

# Man pages
for d in zig-out/share/man/man*; do sudo install -Dm644 -t "/usr/local/share/man/${d##*/}" "$d"/*; done

# Waybar's default config
sudo install -Dm644 -t /etc/xdg/waybar zig-out/etc/xdg/waybar/*

# Shell completions (hyprctl)
sudo install -Dm644 -t /usr/local/share/bash-completion/completions zig-out/share/bash-completion/completions/*
sudo install -Dm644 -t /usr/local/share/fish/vendor_completions.d zig-out/share/fish/vendor_completions.d/*
sudo install -Dm644 -t /usr/local/share/zsh/site-functions zig-out/share/zsh/site-functions/*
```

Hyprland finds its data under `/usr/share` or `/usr/local/share`, so install to
one of those prefixes.
