# Windows: the compositor, its layouts, workspaces, and shortcuts.
# What this feature installs, and where; see packaging's package.mk: this
# tree's, or the one shapebit-packaging installs.
PACKAGING ?= $(firstword $(wildcard $(abspath ../packaging/src)) /usr/share/shapebit/packaging)
include $(PACKAGING)/package.mk

# Hyprland refuses to run as root, as a CI container is, and needs a runtime
# directory even to verify its configuration.
validate: ## Verify the compositor configuration
	runtime=$$(mktemp -d); \
	if [ "$$(id -u)" = 0 ]; then \
	  chown nobody $$runtime && chmod 700 $$runtime; \
	  setpriv --reuid=nobody --regid=nobody --clear-groups env HOME=$$runtime XDG_RUNTIME_DIR=$$runtime \
	    Hyprland --verify-config --config src/hyprland.lua; \
	else \
	  XDG_RUNTIME_DIR=$${XDG_RUNTIME_DIR:-$$runtime} Hyprland --verify-config --config src/hyprland.lua; \
	fi; \
	status=$$?; rm -r $$runtime; exit $$status

install: ## Install into DESTDIR
	install -Dm644 -t $(data)/compositor src/hyprland.lua src/layouts.lua src/shortcuts.lua src/workspaces.lua
	install -Dm644 -t $(share)/wayland-sessions system/desktop.desktop
	install -Dm644 -t $(share)/glib-2.0/schemas system/window-buttons.gschema.override
	install -Dm644 -t $(userunit)/wayland-wm@.service.d system/wayland-wm@.service.d/reload.conf
