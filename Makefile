OUT := zig-out
SUDO := sudo
PREFIX := /usr/local

# Build tools and data: pkg-config, aquamarine (hwdata), libinput (quirks), libxkbcommon (keymaps)
DEPS := \
	hwdata \
	libinput-bin \
	pkg-config \
	xkb-data
# Graphics: aquamarine, hyprgraphics, hyprland, hyprlock, hyprtoolkit
DEPS += \
	libdrm-dev \
	libegl-dev \
	libgbm-dev \
	libgles-dev \
	libpixman-1-dev
# Drawing and text: cairomm, hyprcursor, hyprgraphics, hyprland, hyprlock, hyprtoolkit, pangomm
DEPS += \
	libcairo2-dev \
	libpango1.0-dev
# Images: hyprcursor, hyprgraphics, hyprpaper
DEPS += \
	libjpeg-dev \
	libmagic-dev \
	libpng-dev \
	librsvg2-dev \
	libwebp-dev \
	libzip-dev
# Input: aquamarine, libinput, waybar
DEPS += \
	libevdev-dev \
	libmtdev-dev \
	libseat-dev \
	libudev-dev
# Wayland: wayland, hyprwire
DEPS += \
	libexpat1-dev \
	libffi-dev
# GLib (and gdbus-codegen, glib-compile-resources): glibmm, hyprland, waybar, wofi
DEPS += \
	libglib2.0-dev
# GTK (and gtk+-unix-print-3.0): gtk-layer-shell, gtkmm, waybar, wofi
DEPS += \
	libgtk-3-dev
# sdbus-cpp: hypridle, hyprlock, xdg-desktop-portal-hyprland
DEPS += \
	libsystemd-dev
# uuid: hyprland, xdg-desktop-portal-hyprland
DEPS += \
	uuid-dev
# atkmm
DEPS += \
	libatk1.0-dev
# batsignal
DEPS += \
	libnotify-dev
# gtkmm
DEPS += \
	libepoxy-dev \
	libgdk-pixbuf-2.0-dev
# hyprland
DEPS += \
	libeis-dev \
	liblcms2-dev \
	libreadline-dev \
	libxcb-composite0-dev \
	libxcb-errors-dev \
	libxcb-icccm4-dev \
	libxcb-render0-dev \
	libxcb-res0-dev \
	libxcb-xfixes0-dev \
	libxcb1-dev \
	libxcursor-dev
# hyprlock
DEPS += \
	libpam0g-dev
# hyprtoolkit
DEPS += \
	libiniparser-dev
# libxkbcommon (xkbregistry)
DEPS += \
	libxml2-dev
# waybar
DEPS += \
	libdbusmenu-gtk3-dev \
	libnl-genl-3-dev \
	libpulse-dev
# xdg-desktop-portal-hyprland
DEPS += \
	libpipewire-0.3-dev \
	libspa-0.2-dev

.PHONY: help deps build install dark
.DEFAULT_GOAL := help

help: ## Show targets
	@awk -F ':.*## ' '/^[a-z]+:.*## /{printf "  \033[36m%-8s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

deps: ## Install build tools and libraries
	mise install
	$(SUDO) apt install $(DEPS)

build: ## Build everything into zig-out
	zig build install

install: build ## Build and install to PREFIX (default /usr/local)
	$(SUDO) install -Dm755 -t $(PREFIX)/bin $(OUT)/bin/*
	$(SUDO) install -Dm644 -t /etc/pam.d $(OUT)/etc/pam.d/*
	$(SUDO) install -Dm644 -t $(PREFIX)/lib/systemd/user $(OUT)/lib/systemd/user/*
	$(SUDO) install -Dm644 -t $(PREFIX)/share/dbus-1/services $(OUT)/share/dbus-1/services/*
	$(SUDO) install -Dm644 -t $(PREFIX)/share/xdg-desktop-portal $(OUT)/share/xdg-desktop-portal/*.conf
	# xdg-desktop-portal only reads .portal files from /usr/share
	$(SUDO) install -Dm644 -t /usr/share/xdg-desktop-portal/portals $(OUT)/share/xdg-desktop-portal/portals/*
	$(SUDO) install -Dm644 -t $(PREFIX)/share/wayland-sessions $(OUT)/share/wayland-sessions/*
	$(SUDO) install -Dm644 -t $(PREFIX)/share/hypr $$(find $(OUT)/share/hypr -maxdepth 1 -type f)
	$(SUDO) install -Dm644 -t $(PREFIX)/share/hypr/stubs $(OUT)/share/hypr/stubs/*
	for d in $(OUT)/share/man/man*; do $(SUDO) install -Dm644 -t "$(PREFIX)/share/man/$${d##*/}" "$$d"/*; done
	$(SUDO) install -Dm644 -t /etc/xdg/waybar $(OUT)/etc/xdg/waybar/*
	$(SUDO) install -Dm644 -t $(PREFIX)/share/bash-completion/completions $(OUT)/share/bash-completion/completions/*
	$(SUDO) install -Dm644 -t $(PREFIX)/share/fish/vendor_completions.d $(OUT)/share/fish/vendor_completions.d/*
	$(SUDO) install -Dm644 -t $(PREFIX)/share/zsh/site-functions $(OUT)/share/zsh/site-functions/*

dark: ## Set GTK dark mode
	# GTK4/libadwaita, and via the portal Firefox, Chromium and Electron
	gsettings set org.gnome.desktop.interface color-scheme prefer-dark
	# GTK3
	gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark
