# Screen sharing: what to share, asked in the shell.
# What this feature installs, and where; see packaging's package.mk: this
# tree's, or the one shapebit-packaging installs.
PACKAGING ?= $(firstword $(wildcard $(abspath ../packaging/src)) /usr/share/shapebit/packaging)
include $(PACKAGING)/package.mk

install: ## Install into DESTDIR
	install -Dm755 -t $(libexec) src/share-picker
	install -Dm644 system/xdph.conf $(data)/portal/hypr/xdph.conf
	install -Dm644 system/xdph.service.conf $(userunit)/xdg-desktop-portal-hyprland.service.d/10-picker.conf
