# Network: joining Wi-Fi networks and VPNs from the shell.
# What this feature installs, and where; see packaging's package.mk: this
# tree's, or the one shapebit-packaging installs. The connection agent is Rust
# (Cargo.toml); see packaging's cargo.mk.
PACKAGING ?= $(firstword $(wildcard $(abspath ../packaging/src)) /usr/share/shapebit/packaging)
include $(PACKAGING)/package.mk
include $(PACKAGING)/cargo.mk

install: build crates ## Install into DESTDIR
	install -Dm755 -t $(libexec) $(release)/connection-agent
