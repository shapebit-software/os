# Colors: the system's colors, and the QML module made from them.
# What this feature installs, and where; see packaging's package.mk: this
# tree's, or the one shapebit-packaging installs.
PACKAGING ?= $(firstword $(wildcard $(abspath ../packaging/src)) /usr/share/shapebit/packaging)
include $(PACKAGING)/package.mk

install: ## Install into DESTDIR
	install -Dm644 data/colors.toml $(share)/colors/colors.toml
	install -Dm644 -t $(usr)/lib64/qt6/qml/Colors src/Colors/*
