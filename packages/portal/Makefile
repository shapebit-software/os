# Portal: what applications ask of the desktop.
# What this feature installs, and where; see packaging's package.mk: this
# tree's, or the one shapebit-packaging installs.
PACKAGING ?= $(firstword $(wildcard $(abspath ../packaging/src)) /usr/share/shapebit/packaging)
include $(PACKAGING)/package.mk

install: ## Install into DESTDIR
	install -Dm755 -t $(libexec) src/portal src/share-picker
	install -Dm644 system/portals.conf $(share)/xdg-desktop-portal/shapebit-portals.conf
	install -Dm644 system/shell.portal $(share)/xdg-desktop-portal/portals/shell.portal
	install -Dm644 system/portal.dbus.service $(share)/dbus-1/services/org.freedesktop.impl.portal.desktop.shell.service
	install -Dm644 system/portals.environment.conf $(usr)/lib/environment.d/60-portals.conf
# Screen sharing: Hyprland's portal asks the share picker.
	install -Dm644 system/xdph.conf $(data)/portal/hypr/xdph.conf
	install -Dm644 system/xdph.service.conf $(userunit)/xdg-desktop-portal-hyprland.service.d/10-picker.conf
