# ShapeBit Desktop: the compositor configuration, the shell, and the session.
# Run the targets inside the development container (see README.md).

PREFIX  ?= /usr
DESTDIR ?=

share := $(DESTDIR)$(PREFIX)/share

.PHONY: check run install help

check: ## Verify the compositor configuration and lint the shell
	Hyprland --verify-config --config compositor/hyprland.lua
	qmllint-qt6 --max-warnings 0 --uncreatable-type disable -I shell shell/*.qml

run: ## Run the desktop in a window, inside the current Wayland session
	DESKTOP_SHELL=$(CURDIR)/shell Hyprland --config compositor/hyprland.lua

install: ## Install into DESTDIR
	install -Dm644 -t $(share)/desktop/compositor compositor/*
	install -Dm644 -t $(share)/desktop/shell shell/*
	install -Dm644 -t $(share)/wayland-sessions session/desktop.desktop

help: ## List the targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | sed 's/:.*## /\t/'
