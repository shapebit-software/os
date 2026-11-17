# Repositories: where packages come from, and dnf's settings.
# What this feature installs, and where; see ../package.mk.
include ../package.mk

install: ## Install into DESTDIR
	install -Dm644 no-weak-deps.conf $(share)/dnf5/libdnf.conf.d/50-no-weak-deps.conf
	install -Dm644 no-countme.repo $(share)/dnf5/repos.override.d/50-no-countme.repo
	install -Dm644 -t $(share)/dnf5/repos.d hyprland.repo third-party.repo
	install -Dm644 third-party.asc $(share)/pki/rpm-gpg/third-party.asc
