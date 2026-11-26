# Updates: os-update, its timer, who may run it, and which updates it accepts.
# What this feature installs, and where; see ../package.mk.
include ../package.mk

# The signature policy is the one file in /etc: containers read
# /etc/containers/policy.json instead of containers-common's in /usr, and it has
# no drop-ins (README.md).
install: ## Install into DESTDIR
	install -Dm755 src/os-update $(usr)/libexec/os-update
	install -Dm644 -t $(systemd)/system system/os-update@.service system/os-update.timer
	install -Dm644 system/os-update.preset $(systemd)/system-preset/50-os-update.preset
	install -Dm644 system/os-update.tmpfiles $(usr)/lib/tmpfiles.d/os-update.conf
	install -Dm644 system/os-update.rules $(share)/polkit-1/rules.d/50-os-update.rules
	install -Dm644 data/release-image.pub $(share)/pki/containers/shapebit-os.pub
	install -Dm644 system/shapebit-os.yaml $(share)/containers/registries.d/shapebit-os.yaml
	install -Dm644 system/policy.json $(DESTDIR)/etc/containers/policy.json
