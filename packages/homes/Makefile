# Homes: each person's encrypted home (systemd-homed).
# What this feature installs, and where; see packaging's package.mk: this
# tree's, or the one shapebit-packaging installs.
PACKAGING ?= $(firstword $(wildcard $(abspath ../packaging/src)) /usr/share/shapebit/packaging)
include $(PACKAGING)/package.mk

install: ## Install into DESTDIR
	install -Dm644 system/storage.conf $(systemd)/homed.conf.d/10-storage.conf
	install -Dm644 system/selinux-labels.conf $(systemd)/system/systemd-homed.service.d/10-selinux-labels.conf
