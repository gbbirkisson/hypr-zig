OUT := zig-out
SUDO := sudo
PREFIX := /usr/local

.PHONY: build install

build:
	zig build install

install: build
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
