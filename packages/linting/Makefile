# Linting: how ShapeBit's code is checked without running it.
# What this feature installs, and where; see packaging's package.mk: this
# tree's, or the one shapebit-packaging installs.
PACKAGING ?= $(firstword $(wildcard $(abspath ../packaging/src)) /usr/share/shapebit/packaging)
include $(PACKAGING)/package.mk

install: ## Install into DESTDIR
	install -Dm755 -t $(share)/shapebit/linting src/lint.sh
	install -Dm644 -t $(share)/shapebit/linting data/rustfmt.toml
