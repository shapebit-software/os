# What every feature's Makefile shares: where it installs, the help target,
# its own tests' targets, and the check of what every package keeps to. A
# feature's Makefile includes this, then lists what its `install` target
# installs; check-package fails on a file that no rule installs.
# Usage: make -C packages/FEATURE install DESTDIR=...
#        make -C packages/FEATURE test-unit (or test-integration, check-package)

PREFIX  ?= /usr
DESTDIR ?=

usr      := $(DESTDIR)$(PREFIX)
share    := $(usr)/share
systemd  := $(usr)/lib/systemd
# The desktop's programs and data, apart from the system's.
libexec  := $(usr)/libexec/desktop
data     := $(share)/desktop
userunit := $(systemd)/user

.PHONY: install help test-unit test-integration check-package
.DEFAULT_GOAL := help

help: ## List the targets
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | sed 's/:.*## /\t/'

# The feature's own tests, of a level (their markers), with pytest and the
# testing plugin: the repository's pytest.ini in this tree, or an installed
# shapebit-testing. A level with no tests passes.
pytest = $(if $(wildcard tests),python3 -m pytest -m $1 tests || test $$? = 5,@echo "$(notdir $(CURDIR)): no tests")

test-unit: ## Run this feature's unit tests
	$(call pytest,unit)

test-integration: ## Run this feature's integration tests
	$(call pytest,integration)

check-package: ## Check what every package keeps to: its files installed, its License, its units
	python3 $(PACKAGING)/conformance.py .
