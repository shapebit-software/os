# What every feature's Makefile shares: where it installs, the help target,
# and its own tests' targets. A feature's Makefile includes this, then lists
# what its `install` target installs; packages/tests/integration/test_install.py
# fails on a file that no rule installs.
# Usage: make -C packages/FEATURE install DESTDIR=...
#        make -C packages/FEATURE test-unit (or test-integration)

PREFIX  ?= /usr
DESTDIR ?=

usr      := $(DESTDIR)$(PREFIX)
share    := $(usr)/share
systemd  := $(usr)/lib/systemd
# The desktop's programs and data, apart from the system's.
libexec  := $(usr)/libexec/desktop
data     := $(share)/desktop
userunit := $(systemd)/user

.PHONY: install help test-unit test-integration
.DEFAULT_GOAL := help

help: ## List the targets
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | sed 's/:.*## /\t/'

# The feature's own tests, of a level, with pytest and the testing plugin: the
# repository's pytest.ini in this tree, or an installed shapebit-testing.
# Folders with nothing to collect pass.
test-unit: ## Run this feature's unit tests
	$(if $(wildcard tests/unit),python3 -m pytest tests/unit,@echo "$(notdir $(CURDIR)): no unit tests")

test-integration: ## Run this feature's integration tests
	$(if $(wildcard tests/integration),python3 -m pytest tests/integration,@echo "$(notdir $(CURDIR)): no integration tests")
