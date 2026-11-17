# Updates: os-update, its timer, and who may run it.
# What this feature installs, and where; see ../package.mk.
include ../package.mk

install: ## Install into DESTDIR
	install -Dm755 os-update $(usr)/libexec/os-update
	install -Dm644 -t $(systemd)/system os-update@.service os-update.timer
	install -Dm644 os-update.preset $(systemd)/system-preset/50-os-update.preset
	install -Dm644 os-update.tmpfiles $(usr)/lib/tmpfiles.d/os-update.conf
	install -Dm644 os-update.rules $(share)/polkit-1/rules.d/50-os-update.rules
