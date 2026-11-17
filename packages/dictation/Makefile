# Dictation: speech written into the application in use.
# What this feature installs, and where; see ../package.mk.
include ../package.mk

install: ## Install into DESTDIR
	install -Dm755 -t $(libexec) dictate hear dictate-engine speak
	install -Dm644 -t $(userunit) speech-model.socket speech-model.service
	install -d $(userunit)/sockets.target.wants
	ln -sf ../speech-model.socket $(userunit)/sockets.target.wants/speech-model.socket
