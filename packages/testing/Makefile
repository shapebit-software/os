# Testing: the tests' own tools, which no OS image carries.
# What this feature installs, and where; see packaging's package.mk: this
# tree's, or the one shapebit-packaging installs.
PACKAGING ?= $(firstword $(wildcard $(abspath ../packaging/src)) /usr/share/shapebit/packaging)
include $(PACKAGING)/package.mk

python := $(DESTDIR)$(shell python3 -c 'import sysconfig; print(sysconfig.get_path("purelib", vars={"base": "$(PREFIX)"}))')
# pytest loads the plugin and the fixtures of an installed shapebit-testing by
# its entry points; in this tree, the root pytest.ini loads them.
info := $(python)/shapebit_testing-0.dist-info

install: ## Install into DESTDIR
	install -Dm644 -t $(python)/testing src/testing/*.py
# Its commands: what a change touches, and the machines.
	chmod 755 $(python)/testing/changed.py $(python)/testing/machine.py
	install -Dm644 -t $(python)/testing/fakes src/testing/fakes/*.py
	install -Dm644 -t $(info) data/METADATA data/entry_points.txt
	cd e2e && find . -type f ! -path '*/__pycache__/*' -exec install -Dm644 {} $(share)/shapebit/testing/e2e/{} \;
	chmod 755 $(share)/shapebit/testing/e2e/run.py $(share)/shapebit/testing/e2e/new-needle.py
