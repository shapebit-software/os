# Testing: the tests' own tools, which no OS image carries.
# What this feature installs, and where; see ../package.mk.
include ../package.mk

python := $(DESTDIR)$(shell python3 -c 'import sysconfig; print(sysconfig.get_path("purelib", vars={"base": "$(PREFIX)"}))')

install: ## Install into DESTDIR
	install -Dm644 -t $(python)/testing src/testing/*.py
