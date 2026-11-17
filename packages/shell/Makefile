# The shell: bars, dock, panels, Settings, notifications, and the lock screen.
# What this feature installs, and where; see ../package.mk.
include ../package.mk

# The shell's folders import each other as qs.<folder>, which qmllint looks up
# in a directory named qs; Colors is the image's source of it.
lint: ## Lint the shell
	lint=$$(mktemp -d); ln -s $(CURDIR) $$lint/qs; \
	qmllint-qt6 --max-warnings 0 --uncreatable-type disable -I $$lint -I $(CURDIR)/../colors \
	  $(filter-out %/tst_%.qml,$(wildcard *.qml */*.qml)); \
	status=$$?; rm -r $$lint; exit $$status

install: ## Install into DESTDIR
	# Every file of the shell, without its tests (tst_*.qml, test_*.py), which
	# sit beside its code, and what builds it.
	find . -type f ! -name 'tst_*' ! -name 'test_*' ! -name Makefile ! -name '*.spec' ! -name README.md \
	  -exec install -Dm644 {} $(data)/shell/{} \;
