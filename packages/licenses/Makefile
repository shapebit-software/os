# Licenses: Settings > Licenses, and the notices some packages lack.
# What this feature installs, and where; see packaging's package.mk: this
# tree's, or the one shapebit-packaging installs.
PACKAGING ?= $(firstword $(wildcard $(abspath ../packaging/src)) /usr/share/shapebit/packaging)
include $(PACKAGING)/package.mk

install: ## Install into DESTDIR
	install -Dm755 -t $(libexec) src/licenses
# The texts that no source RPM of their package holds (tools/notices.py).
	for f in $$(cd data/notices && find . -type f); do install -Dm644 data/notices/$$f $(share)/licenses/$$f; done
