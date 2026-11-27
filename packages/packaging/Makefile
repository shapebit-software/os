# Packaging: how a ShapeBit package is built.
# What this feature installs, and where; see package.mk, its own.
PACKAGING ?= $(abspath src)
include $(PACKAGING)/package.mk

kit := $(share)/shapebit/packaging

install: ## Install into DESTDIR
	install -Dm644 -t $(kit) src/package.macros src/package.mk src/cargo.mk data/rpmlint.toml
	install -Dm755 -t $(kit) src/crates.py src/conformance.py
	install -Dm644 -t $(kit)/licenses data/licenses/*
	install -Dm644 data/macros.shapebit $(usr)/lib/rpm/macros.d/macros.shapebit
