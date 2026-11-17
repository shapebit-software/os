# Development: the desktop in a window (make run, from the repository root).
# Run it inside the development container (make dev).

# What development adds, in the repository's build folder: the extras that
# `make run` downloads (the assistant's and dictation's models), the model
# server and speech engine that `make dev-assistant` puts there
# (dev-assistant.sh), and every feature, as its Makefile installs it into the
# image: Settings > Licenses reads their license texts, and the portal their colors.
dev      := $(abspath $(CURDIR)/../build/dev)
system   := $(dev)/system
packages := $(abspath $(CURDIR)/../packages)

# The host's system bus, which the development container shares here: the
# shell needs it for the network and Bluetooth.
host_bus := /run/host/run/dbus/system_bus_socket

.PHONY: run

# The host session's desktop name is not this one's; Hyprland sets its own.
# The fonts include the OS image's (fonts.conf). The desktop has a session bus
# of its own, with its portals and the Portal Tester (run). The extras are the
# person's own here, so Settings > Assistant downloads them without an
# administrator.
run:
	mkdir -p $(dev)/extras
	rm -r -f $(system)
	for makefile in $(packages)/*/Makefile; do \
	  $(MAKE) -C $$(dirname $$makefile) install DESTDIR=$(system) IMAGE_VERSION=dev IMAGE_REVISION=dev FEDORA=dev || exit 1; \
	done
	env -u XDG_CURRENT_DESKTOP DESKTOP_SHELL=$(packages)/shell QML_IMPORT_PATH=$(packages)/colors \
	FONTCONFIG_FILE=$(CURDIR)/fonts.conf DEV_SYSTEM=$(system) \
	EXTRAS_DIR=$(dev)/extras DICTATION_PARAKEET=$(dev)/extras/parakeet \
	LICENSES_DIR=$(system)/usr/share/licenses \
	$(if $(wildcard $(dev)/llama/llama-server),ASSISTANT_LLAMA=$(dev)/llama/llama-server) \
	$(if $(wildcard $(dev)/python),PYTHONPATH=$(dev)/python) \
	$(if $(wildcard $(host_bus)),DBUS_SYSTEM_BUS_ADDRESS=unix:path=$(host_bus)) \
	./run
