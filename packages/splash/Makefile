# Splash: the boot splash, and its hand-off to the login screen.
# What this feature installs, and where; see packaging's package.mk: this
# tree's, or the one shapebit-packaging installs.
PACKAGING ?= $(firstword $(wildcard $(abspath ../packaging/src)) /usr/share/shapebit/packaging)
include $(PACKAGING)/package.mk

# The theme takes the images of Fedora's spinner theme, except its watermark,
# where that theme is installed (in the image build: the spec's BuildRequires).
spinner := $(filter-out %/watermark.png,$(wildcard /usr/share/plymouth/themes/spinner/*.png))

install: ## Install into DESTDIR
	install -Dm644 system/30-splash.toml $(usr)/lib/bootc/kargs.d/30-splash.toml
	install -Dm644 -t $(share)/plymouth/themes/boot data/boot.plymouth data/watermark.png
	$(foreach image,$(spinner),ln -sf ../spinner/$(notdir $(image)) $(share)/plymouth/themes/boot/;)
	install -Dm644 system/sddm-splash.conf $(systemd)/system/sddm.service.d/10-splash.conf
