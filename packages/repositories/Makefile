# Repositories: where packages come from, and dnf's settings.
# What this feature installs, and where; see ../package.mk.
include ../package.mk

install: ## Install into DESTDIR
	install -Dm644 system/no-weak-deps.conf $(share)/dnf5/libdnf.conf.d/50-no-weak-deps.conf
	install -Dm644 system/no-countme.repo $(share)/dnf5/repos.override.d/50-no-countme.repo
	install -Dm644 -t $(share)/dnf5/repos.d system/hyprland.repo system/third-party.repo
	install -Dm644 data/third-party.asc $(share)/pki/rpm-gpg/third-party.asc
