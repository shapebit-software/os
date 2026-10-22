# ShapeBit Desktop: the compositor configuration, the shell, and the session.
# Run the targets inside the development container (see README.md).

PREFIX  ?= /usr
DESTDIR ?=

share := $(DESTDIR)$(PREFIX)/share

# The host's system bus, which the development container shares here: the
# shell needs it for the network and Bluetooth.
host_bus := /run/host/run/dbus/system_bus_socket

.PHONY: check run install help

check: ## Verify the compositor configuration and lint the shell
	Hyprland --verify-config --config compositor/hyprland.lua
	qmllint-qt6 --max-warnings 0 --uncreatable-type disable -I shell shell/*.qml

# The host session's desktop name is not this one's; Hyprland sets its own.
# The fonts include the OS image's (fonts.conf).
run: ## Run the desktop in a window, inside the current Wayland session
	env -u XDG_CURRENT_DESKTOP DESKTOP_SHELL=$(CURDIR)/shell FONTCONFIG_FILE=$(CURDIR)/fonts.conf \
	$(if $(wildcard $(host_bus)),DBUS_SYSTEM_BUS_ADDRESS=unix:path=$(host_bus)) \
	start-hyprland -- --config compositor/hyprland.lua

install: ## Install into DESTDIR
	install -Dm644 -t $(share)/desktop/compositor compositor/*
	install -Dm644 -t $(share)/desktop/shell shell/*
	install -Dm644 -t $(share)/wayland-sessions session/desktop.desktop

help: ## List the targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | sed 's/:.*## /\t/'
