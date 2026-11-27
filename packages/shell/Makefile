# The shell: bars, dock, panels, Settings, notifications, and the lock screen.
# What this feature installs, and where; see packaging's package.mk: this
# tree's, or the one shapebit-packaging installs.
PACKAGING ?= $(firstword $(wildcard $(abspath ../packaging/src)) /usr/share/shapebit/packaging)
include $(PACKAGING)/package.mk

# The shell's folders import each other as qs.<folder>, which qmllint looks up
# in a directory named qs; Colors is the image's source of it.
lint: ## Lint the shell
	lint=$$(mktemp -d); ln -s $(CURDIR)/src $$lint/qs; \
	qmllint-qt6 --max-warnings 0 --uncreatable-type disable -I $$lint -I $(CURDIR)/../colors/src \
	  $(wildcard src/*.qml src/*/*.qml); \
	status=$$?; rm -r $$lint; exit $$status

install: ## Install into DESTDIR
	# Every file of the shell's code.
	cd src && find . -type f -exec install -Dm644 {} $(data)/shell/{} \;
# Where features' packages put what they add (services/Features.qml).
	install -d $(data)/shell/features
	install -Dm644 -t $(userunit) system/shell.service
	install -d $(userunit)/graphical-session.target.wants
	ln -sf ../shell.service $(userunit)/graphical-session.target.wants/shell.service
