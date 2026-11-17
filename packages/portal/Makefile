# Portal: what applications ask of the desktop.
# What this feature installs, and where; see ../package.mk.
include ../package.mk

install: ## Install into DESTDIR
	install -Dm755 -t $(libexec) portal
	install -Dm644 portals.conf $(share)/xdg-desktop-portal/shapebit-portals.conf
	install -Dm644 shell.portal $(share)/xdg-desktop-portal/portals/shell.portal
	install -Dm644 portal.dbus.service $(share)/dbus-1/services/org.freedesktop.impl.portal.desktop.shell.service
	install -Dm644 portals.environment.conf $(usr)/lib/environment.d/60-portals.conf
