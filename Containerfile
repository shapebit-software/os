# ShapeBit OS: bootc image, booted by systemd-boot from a signed UKI.
# This is the unsealed system; Containerfile.seal adds the UKI (see
# scripts/image.sh), and Containerfile.installer builds the installer medium
# from it. Signing needs the key as build secrets signing.key and signing.crt, and
# KEYS_ID, which changes with it.
# Only signed binaries and public keys reach the image.
ARG FEDORA_VERSION=44
FROM quay.io/fedora/fedora-bootc:${FEDORA_VERSION} AS system

LABEL org.opencontainers.image.title="ShapeBit OS" \
      org.opencontainers.image.url="https://shapebit.software" \
      org.opencontainers.image.source="https://github.com/shapebit-software/image"

# Files under rootfs/ are copied verbatim; their paths mirror the target system.
COPY rootfs/ /

# The base image ships only GRUB; bootc installs systemd-boot from this package.
# The base image has only the C locale; the langpacks add the locales that the
# installer offers.
# SDDM is the login screen; its greeter runs in Weston (sddm-wayland-generic)
# and draws with Mesa. Fedora's presets enable sddm.service.
# dnf state in /var and /run is removed, since bootc ignores it on install;
# so are SDDM's runtime directory, which tmpfiles.d creates on each boot, and
# libX11's empty cache.
RUN dnf -y install systemd-boot-unsigned glibc-all-langpacks \
      sddm sddm-wayland-generic mesa-dri-drivers && dnf clean all && \
    rm -rf /var/log/dnf5.log /var/lib/dnf /var/cache/libdnf5 /var/cache/ldconfig /run/dnf \
      /run/sddm /var/cache/libX11

# The desktop's packages, which the desktop lists with the reason for each
# (build context `desktop`, its file packages): Hyprland and Quickshell, the
# session, and what the shell runs. Fedora has no Hyprland, so it comes from a
# third-party COPR for now; the repository is used only for this build and is
# not left in the image. Hyprland's own session entries are removed, so the
# login screen offers only the desktop's.
RUN --mount=type=bind,from=desktop,source=packages,target=/run/desktop-packages <<'EOF'
set -euo pipefail
cat >/etc/yum.repos.d/hyprland.repo <<'REPO'
[hyprland]
name=Hyprland (COPR sdegler/hyprland)
baseurl=https://download.copr.fedorainfracloud.org/results/sdegler/hyprland/fedora-$releasever-$basearch/
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/sdegler/hyprland/pubkey.gpg
REPO
dnf -y install $(sed 's/#.*//' /run/desktop-packages)
dnf clean all
rm /etc/yum.repos.d/hyprland.repo
rm /usr/share/wayland-sessions/hyprland.desktop
rm -rf /var/log/dnf5.log /var/lib/dnf /var/cache/libdnf5 /var/cache/ldconfig /run/dnf
EOF

# Applications come from Flatpak, with Flathub's remote
# (rootfs/usr/share/flatpak/remotes.d/flathub.flatpakrepo, as Flathub
# publishes it), which Flatpak adds by itself the first time it runs; its
# environment generators put the applications in the session's Apps.
# desktop-file-utils lets Flatpak record which applications open which types.
RUN dnf -y install flatpak desktop-file-utils && dnf clean all && \
    rm -rf /var/log/dnf5.log /var/lib/dnf /var/cache/libdnf5 /var/cache/ldconfig /run/dnf

# Files (Nautilus), the one built-in app that is not a Flatpak, since GNOME
# publishes none of it; it updates and rolls back with the OS. The other
# apps are recommended in Welcome and installed from Flathub. Where two apps
# open the same type, the desktop's default is in
# rootfs/usr/share/applications/shapebit-mimeapps.list. Its thumbnailers draw
# the previews of images and videos.
RUN dnf -y install nautilus glycin-thumbnailer gst-thumbnailers && dnf clean all && \
    rm -rf /var/log/dnf5.log /var/lib/dnf /var/cache/libdnf5 /var/cache/ldconfig /run/dnf

# os-update.timer checks for system updates (rootfs/usr/lib/systemd/system).
RUN systemctl set-default graphical.target && systemctl preset os-update.timer

# Distrobox, for development tools in containers (Podman is in the base
# image). New containers start from Fedora's toolbox image of this image's
# Fedora version, rather than its latest.
RUN dnf -y install distrobox && dnf clean all && \
    rm -rf /var/log/dnf5.log /var/lib/dnf /var/cache/libdnf5 /var/cache/ldconfig /run/dnf && \
    mkdir -p /usr/share/distrobox && \
    echo "container_image_default=\"registry.fedoraproject.org/fedora-toolbox:$(rpm -E %fedora)\"" \
      >/usr/share/distrobox/distrobox.conf

# Logins for systemd-homed users need pam_systemd_home. authselect's checksum
# in /var is dropped, as in the base image; the configuration lives in /etc.
RUN authselect enable-feature with-systemd-homed && rm -r /var/lib/authselect

# The initramfs must carry /usr/lib/composefs/setup-root-conf.toml, so it is
# rebuilt after rootfs/ is in place.
RUN kernel=$(basename /usr/lib/modules/*) && \
    dracut --force "/usr/lib/modules/$kernel/initramfs.img" "$kernel"

# Signing tools, used by the stages below and never part of the final image.
FROM system AS tools
RUN dnf -y install sbsigntools && mkdir /out

# systemd-boot, signed; bootctl installs the *.signed copy when present.
FROM tools AS bootloader
ARG KEYS_ID
RUN --mount=type=secret,id=signing.key --mount=type=secret,id=signing.crt \
    sbsign --key /run/secrets/signing.key --cert /run/secrets/signing.crt \
      --output /out/systemd-bootx64.efi.signed \
      /usr/lib/systemd/boot/efi/systemd-bootx64.efi

# The certificate that the person enrolls in shim's MOK manager (esp-shim).
FROM tools AS certificate
ARG KEYS_ID
RUN --mount=type=secret,id=signing.crt \
    openssl x509 -in /run/secrets/signing.crt -outform DER -out /out/enroll-this-key.cer

# The desktop's files (build context `desktop`), installed by its Makefile.
FROM tools AS desktop-files
RUN dnf -y install make
RUN --mount=type=bind,from=desktop,target=/src make -C /src install DESTDIR=/out

FROM system
COPY --from=desktop-files /out/ /
# The desktop's settings defaults (window-buttons.gschema.override) apply
# once the schemas are compiled again.
RUN glib-compile-schemas /usr/share/glib-2.0/schemas
COPY --from=bootloader /out/ /usr/lib/systemd/boot/efi/
COPY --from=certificate /out/ /usr/share/secureboot/
# Identifies this build; last, so a new version rebuilds only this layer.
ARG IMAGE_VERSION
LABEL org.opencontainers.image.version="$IMAGE_VERSION"
RUN test -n "$IMAGE_VERSION" && echo "IMAGE_VERSION=$IMAGE_VERSION" >>/usr/lib/os-release
RUN bootc container lint
