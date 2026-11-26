# What every feature's Makefile shares: where it installs, and the help target.
# A feature's Makefile includes this, then lists what its `install` target
# installs; packages/test_install.py fails on a file that no rule installs.
# Usage: make -C packages/FEATURE install DESTDIR=...

PREFIX  ?= /usr
DESTDIR ?=

usr      := $(DESTDIR)$(PREFIX)
share    := $(usr)/share
systemd  := $(usr)/lib/systemd
# The desktop's programs and data, apart from the system's.
libexec  := $(usr)/libexec/desktop
data     := $(share)/desktop
userunit := $(systemd)/user

.PHONY: install help
.DEFAULT_GOAL := help

help: ## List the targets
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | sed 's/:.*## /\t/'
