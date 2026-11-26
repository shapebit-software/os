# Extras: what is too large for the OS image, such as speech and language models.
# What this feature installs, and where; see ../package.mk.
include ../package.mk

install: ## Install into DESTDIR
	install -Dm755 -t $(libexec) src/extra
	install -Dm644 -t $(data) data/extras.json
	install -Dm644 system/extras.tmpfiles $(usr)/lib/tmpfiles.d/extras.conf
	install -d $(share)/licenses && cp -r data/licenses/. $(share)/licenses/
