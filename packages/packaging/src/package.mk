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

# A feature that adds to the shell (src/feature.qml) has its QML in src/shell,
# the module qs.FEATURE. lint checks it against the shell's modules and other
# features', which qmllint looks up in a folder named qs, as installed: this
# tree's, or the installed shell's; and against Colors, this tree's or the
# system's.
ifneq ($(wildcard src/feature.qml),)
SHELL_QML ?= $(firstword $(wildcard $(abspath ../shell/src)) /usr/share/desktop/shell)
FEATURES_QML := $(filter-out $(CURDIR)/src/shell,$(wildcard $(abspath ..)/*/src/shell))
.PHONY: lint
lint: ## Lint this feature's QML
	lint=$$(mktemp -d); mkdir $$lint/qs; \
	for d in $(SHELL_QML)/*/; do ln -s $$d $$lint/qs/; done; \
	for d in $(FEATURES_QML); do ln -sfn $$d $$lint/qs/$$(basename $$(dirname $$(dirname $$d))); done; \
	ln -sfn $(CURDIR)/src/shell $$lint/qs/$(notdir $(CURDIR)); \
	qmllint-qt6 --max-warnings 0 --uncreatable-type disable -I $$lint $(addprefix -I ,$(wildcard $(abspath ../colors/src))) \
	  src/shell/*.qml src/feature.qml; \
	status=$$?; rm -r $$lint; exit $$status
endif
