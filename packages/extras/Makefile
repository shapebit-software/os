# Extras: what is too large for the OS image, such as speech and language models.
# What this feature installs, and where; see ../package.mk.
include ../package.mk

install: ## Install into DESTDIR
	install -Dm755 -t $(libexec) extra
	install -Dm644 -t $(data) extras.json
	install -Dm644 extras.tmpfiles $(usr)/lib/tmpfiles.d/extras.conf
	install -d $(share)/licenses && cp -r licenses/. $(share)/licenses/
