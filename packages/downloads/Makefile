# Downloads: the one queue of what the desktop downloads and installs.
# What this feature installs, and where; see ../package.mk.
include ../package.mk

install: ## Install into DESTDIR
	install -Dm755 -t $(libexec) downloads
	install -Dm644 -t $(userunit) downloads.service
	install -d $(userunit)/graphical-session.target.wants
	ln -sf ../downloads.service $(userunit)/graphical-session.target.wants/downloads.service
