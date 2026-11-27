# Font: Instrument Sans, the system's font.
# What this feature installs, and where; see packaging's package.mk: this
# tree's, or the one shapebit-packaging installs.
PACKAGING ?= $(firstword $(wildcard $(abspath ../packaging/src)) /usr/share/shapebit/packaging)
include $(PACKAGING)/package.mk

install: ## Install into DESTDIR
	install -Dm644 data/InstrumentSans.ttf $(share)/fonts/instrument-sans/InstrumentSans.ttf
	install -Dm644 data/OFL.txt $(share)/licenses/instrument-sans/OFL.txt
