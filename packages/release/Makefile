# Release: ShapeBit's identity, with the image's version and commit.
# What this feature installs, and where; see ../package.mk.
include ../package.mk

install: ## Install into DESTDIR
	install -Dm644 os-release $(usr)/lib/os-release
	printf 'IMAGE_VERSION=%s\nIMAGE_REVISION=%s\n' \
	  '$(or $(IMAGE_VERSION),$(error IMAGE_VERSION is not set))' \
	  '$(or $(IMAGE_REVISION),$(error IMAGE_REVISION is not set))' >>$(usr)/lib/os-release
