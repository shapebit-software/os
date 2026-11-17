# Colors: the system's colors, and the QML module made from them.
# What this feature installs, and where; see ../package.mk.
include ../package.mk

install: ## Install into DESTDIR
	install -Dm644 colors.toml $(share)/colors/colors.toml
	install -Dm644 -t $(usr)/lib64/qt6/qml/Colors Colors/*
