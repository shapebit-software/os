# Login: the login screen, and the secrets it unlocks.
# What this feature installs, and where; see ../package.mk.
include ../package.mk

install: ## Install into DESTDIR
	install -Dm644 src/compositor.lua $(usr)/lib/sddm/compositor.lua
	install -Dm644 system/login.conf $(usr)/lib/sddm/sddm.conf.d/10-login.conf
	install -Dm644 -t $(share)/sddm/themes/login src/theme/*
	install -Dm644 system/geoclue.tmpfiles $(usr)/lib/tmpfiles.d/geoclue.conf
