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

Build tools (Zig, bison, binutils, Python) are pinned in `.tool-versions`.

```
# Install build tools
mise install

# Install dependencies
sudo apt install \
  hwdata \
  libcairo2-dev \
  libdrm-dev \
  libegl-dev \
  libeis-dev \
  libevdev-dev \
  libexpat1-dev \
  libffi-dev \
  libgbm-dev \
  libgles-dev \
  libglib2.0-dev \
  libgtk-3-dev \
  libiniparser-dev \
  libinput-bin \
  libjpeg-dev \
  liblcms2-dev \
  libmagic-dev \
  libmtdev-dev \
  libnotify-dev \
  libpam0g-dev \
  libpango1.0-dev \
  libpipewire-0.3-dev \
  libpixman-1-dev \
  libpng-dev \
  libreadline-dev \
  librsvg2-dev \
  libseat-dev \
  libspa-0.2-dev \
  libsystemd-dev \
  libudev-dev \
  libwebp-dev \
  libxcursor-dev \
  libzip-dev \
  pkg-config \
  uuid-dev \
  xkb-data
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
  waybar \
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

# Shell completions (hyprctl)
sudo install -Dm644 -t /usr/local/share/bash-completion/completions zig-out/share/bash-completion/completions/*
sudo install -Dm644 -t /usr/local/share/fish/vendor_completions.d zig-out/share/fish/vendor_completions.d/*
sudo install -Dm644 -t /usr/local/share/zsh/site-functions zig-out/share/zsh/site-functions/*
```

Hyprland finds its data under `/usr/share` or `/usr/local/share`, so install to
one of those prefixes.
