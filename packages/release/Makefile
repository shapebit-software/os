# Release: ShapeBit's identity, with the image's version and commit, in place
# of Fedora's identity package (release.spec).
# What this feature installs, and where; see ../package.mk.
include ../package.mk

fedora = $(or $(FEDORA),$(error FEDORA is not set))
version = $(or $(IMAGE_VERSION),$(error IMAGE_VERSION is not set))

install: ## Install into DESTDIR
	install -Dm644 system/os-release $(usr)/lib/os-release
	printf 'IMAGE_VERSION=%s\nIMAGE_REVISION=%s\n' '$(version)' \
	  '$(or $(IMAGE_REVISION),$(error IMAGE_REVISION is not set))' >>$(usr)/lib/os-release
# The release file that tools read for the release of Fedora's packages, and
# the platform's CPE.
	printf 'ShapeBit release %s\n' '$(fedora)' >$(usr)/lib/fedora-release
	printf 'cpe:/o:shapebit:shapebit:%s\n' '$(version)' >$(usr)/lib/system-release-cpe
	install -Dm644 -t $(usr)/lib system/issue system/issue.net
	install -Dm644 system/macros.dist $(usr)/lib/rpm/macros.d/macros.dist
	printf '%%fedora              %s\n%%fc%s                1\n' '$(fedora)' '$(fedora)' >>$(usr)/lib/rpm/macros.d/macros.dist
	install -Dm644 system/dnf-defaults.conf $(share)/dnf5/libdnf.conf.d/20-defaults.conf
# The paths in /etc where programs look for them: links into /usr, as every
# Fedora identity package has them.
	install -d $(DESTDIR)/etc
	ln -sf ../usr/lib/os-release $(DESTDIR)/etc/os-release
	ln -sf ../usr/lib/fedora-release $(DESTDIR)/etc/fedora-release
	ln -sf fedora-release $(DESTDIR)/etc/redhat-release
	ln -sf fedora-release $(DESTDIR)/etc/system-release
	ln -sf ../usr/lib/system-release-cpe $(DESTDIR)/etc/system-release-cpe
	ln -sf ../usr/lib/issue $(DESTDIR)/etc/issue
	ln -sf ../usr/lib/issue.net $(DESTDIR)/etc/issue.net
	install -d $(DESTDIR)/etc/issue.d
