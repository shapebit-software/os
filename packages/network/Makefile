# Network: joining Wi-Fi networks and VPNs from the shell.
# What this feature installs, and where; see ../package.mk. The connection
# agent is Rust (Cargo.toml); see ../cargo.mk.
include ../package.mk
include ../cargo.mk

install: build crates ## Install into DESTDIR
	install -Dm755 -t $(libexec) $(release)/connection-agent
