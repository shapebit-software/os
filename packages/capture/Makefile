# Capture: screenshots, screen and voice recordings, and the camera.
# What this feature installs, and where; see packaging's package.mk: this
# tree's, or the one shapebit-packaging installs.
PACKAGING ?= $(firstword $(wildcard $(abspath ../packaging/src)) /usr/share/shapebit/packaging)
include $(PACKAGING)/package.mk

install: ## Install into DESTDIR
	install -Dm755 -t $(libexec) src/camera src/skip-silence
# What it shows in the shell: its QML, the module qs.capture, in the shell's
# folder, and what it adds there (packages/shell/src/services/Features.qml).
	install -Dm644 -t $(data)/shell/capture src/shell/*.qml src/shell/qmldir
	install -Dm644 src/feature.qml $(data)/shell/features/capture.qml
