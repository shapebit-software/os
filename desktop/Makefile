# ShapeBit Desktop: the compositor configuration, the shell, and the session.
# Run the targets inside the development container (see README.md).

PREFIX  ?= /usr
DESTDIR ?=

share := $(DESTDIR)$(PREFIX)/share

# The host's system bus, which the development container shares here: the
# shell needs it for the network and Bluetooth.
host_bus := /run/host/run/dbus/system_bus_socket

.PHONY: check run install help

# The shell's folders import each other as qs.<folder>, which qmllint looks up
# in a directory named qs.
check: ## Verify the compositor configuration and lint the shell
	Hyprland --verify-config --config compositor/hyprland.lua
	lint=$$(mktemp -d); ln -s $(CURDIR)/shell $$lint/qs; \
	qmllint-qt6 --max-warnings 0 --uncreatable-type disable -I $$lint shell/*.qml shell/*/*.qml; \
	status=$$?; rm -rf $$lint; exit $$status

# The host session's desktop name is not this one's; Hyprland sets its own.
# The fonts include the OS image's (fonts.conf). The desktop has a session
# bus of its own, with its portals and the Portal Tester (dev/run).
run: ## Run the desktop in a window, inside the current Wayland session
	env -u XDG_CURRENT_DESKTOP DESKTOP_SHELL=$(CURDIR)/shell FONTCONFIG_FILE=$(CURDIR)/fonts.conf \
	$(if $(wildcard $(host_bus)),DBUS_SYSTEM_BUS_ADDRESS=unix:path=$(host_bus)) \
	dev/run

install: ## Install into DESTDIR
	install -Dm644 -t $(share)/desktop/compositor compositor/*
	find shell -type f -exec install -Dm644 {} $(share)/desktop/{} \;
	install -Dm644 -t $(share)/wayland-sessions session/desktop.desktop
	install -Dm644 session/portals.conf $(share)/xdg-desktop-portal/shapebit-portals.conf
	install -Dm644 -t $(share)/glib-2.0/schemas session/window-buttons.gschema.override
	install -Dm644 session/shell.portal $(share)/xdg-desktop-portal/portals/shell.portal
	install -Dm755 -t $(DESTDIR)$(PREFIX)/libexec/desktop session/portal session/share-picker session/connection-agent session/app-install session/app-catalog session/app-remove
	install -Dm644 -t $(share)/desktop/browsers session/fedora.filter
	install -Dm644 -t $(DESTDIR)$(PREFIX)/lib/systemd/user session/app-update.service session/app-update.timer
	install -d $(DESTDIR)$(PREFIX)/lib/systemd/user/timers.target.wants
	ln -sf ../app-update.timer $(DESTDIR)$(PREFIX)/lib/systemd/user/timers.target.wants/app-update.timer
	install -Dm644 session/portal.dbus.service $(share)/dbus-1/services/org.freedesktop.impl.portal.desktop.shell.service
	install -Dm644 session/xdph.conf $(share)/desktop/portal/hypr/xdph.conf
	install -Dm644 session/xdph.service.conf $(DESTDIR)$(PREFIX)/lib/systemd/user/xdg-desktop-portal-hyprland.service.d/10-picker.conf
	install -Dm644 session/portals.environment.conf $(DESTDIR)$(PREFIX)/lib/environment.d/60-portals.conf

help: ## List the targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | sed 's/:.*## /\t/'
