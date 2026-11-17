# Boot: kernel arguments, the composefs root, systemd-boot, and the EFI shim.
# What this feature installs, and where; see ../package.mk.
include ../package.mk

install: ## Install into DESTDIR
	install -Dm644 -t $(usr)/lib/bootc/kargs.d 10-console.toml 20-root.toml
	install -Dm644 setup-root-conf.toml $(usr)/lib/composefs/setup-root-conf.toml
	install -Dm755 esp-shim $(usr)/libexec/esp-shim
