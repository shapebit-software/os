# Boot: kernel arguments, the composefs root, systemd-boot, and the EFI shim.
# What this feature installs, and where; see packaging's package.mk: this
# tree's, or the one shapebit-packaging installs.
PACKAGING ?= $(firstword $(wildcard $(abspath ../packaging/src)) /usr/share/shapebit/packaging)
include $(PACKAGING)/package.mk

install: ## Install into DESTDIR
	install -Dm644 -t $(usr)/lib/bootc/kargs.d system/10-console.toml system/20-root.toml
	install -Dm644 system/setup-root-conf.toml $(usr)/lib/composefs/setup-root-conf.toml
	install -Dm755 src/esp-shim $(usr)/libexec/esp-shim
