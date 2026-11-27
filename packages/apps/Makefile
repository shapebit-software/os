# Apps: Flathub, the built-in apps, and installing and updating apps.
# What this feature installs, and where; see packaging's package.mk: this
# tree's, or the one shapebit-packaging installs.
PACKAGING ?= $(firstword $(wildcard $(abspath ../packaging/src)) /usr/share/shapebit/packaging)
include $(PACKAGING)/package.mk

install: ## Install into DESTDIR
	install -Dm755 -t $(libexec) src/app-install src/app-catalog src/app-remove
	install -Dm644 -t $(data)/browsers data/fedora.filter
	install -Dm644 -t $(userunit) system/app-update.service system/app-update.timer
	install -d $(userunit)/timers.target.wants
	ln -sf ../app-update.timer $(userunit)/timers.target.wants/app-update.timer
	install -Dm644 system/flathub.flatpakrepo $(share)/flatpak/remotes.d/flathub.flatpakrepo
	install -Dm644 system/shapebit-mimeapps.list $(share)/applications/shapebit-mimeapps.list
	# New Distrobox containers start from Fedora's toolbox image of this Fedora
	# version, rather than its latest.
	install -d $(share)/distrobox
	echo 'container_image_default="registry.fedoraproject.org/fedora-toolbox:$(or $(FEDORA),$(error FEDORA is not set))"' \
	  >$(share)/distrobox/distrobox.conf
