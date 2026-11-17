# Apps: Flathub, the built-in apps, and installing and updating apps.
# What this feature installs, and where; see ../package.mk.
include ../package.mk

install: ## Install into DESTDIR
	install -Dm755 -t $(libexec) app-install app-catalog app-remove
	install -Dm644 -t $(data)/browsers fedora.filter
	install -Dm644 -t $(userunit) app-update.service app-update.timer
	install -d $(userunit)/timers.target.wants
	ln -sf ../app-update.timer $(userunit)/timers.target.wants/app-update.timer
	install -Dm644 flathub.flatpakrepo $(share)/flatpak/remotes.d/flathub.flatpakrepo
	install -Dm644 shapebit-mimeapps.list $(share)/applications/shapebit-mimeapps.list
	# New Distrobox containers start from Fedora's toolbox image of this Fedora
	# version, rather than its latest.
	install -d $(share)/distrobox
	echo 'container_image_default="registry.fedoraproject.org/fedora-toolbox:$(or $(FEDORA),$(error FEDORA is not set))"' \
	  >$(share)/distrobox/distrobox.conf
