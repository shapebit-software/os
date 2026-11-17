# Homes: each person's encrypted home (systemd-homed).
# What this feature installs, and where; see ../package.mk.
include ../package.mk

install: ## Install into DESTDIR
	install -Dm644 storage.conf $(systemd)/homed.conf.d/10-storage.conf
	install -Dm644 selinux-labels.conf $(systemd)/system/systemd-homed.service.d/10-selinux-labels.conf
