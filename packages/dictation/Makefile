# Dictation: speech written into the application in use.
# What this feature installs, and where; see packaging's package.mk: this
# tree's, or the one shapebit-packaging installs.
PACKAGING ?= $(firstword $(wildcard $(abspath ../packaging/src)) /usr/share/shapebit/packaging)
include $(PACKAGING)/package.mk

install: ## Install into DESTDIR
	install -Dm755 -t $(libexec) src/dictate src/hear src/dictate-engine
	install -Dm644 -t $(userunit) system/speech-model.socket system/speech-model.service
	install -d $(userunit)/sockets.target.wants
	ln -sf ../speech-model.socket $(userunit)/sockets.target.wants/speech-model.socket
