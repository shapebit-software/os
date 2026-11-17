# ShapeBit's system: its files under usr/ (the system's /usr), and what it needs
# from Fedora, each with the reason for it; and the release package, ShapeBit's
# identity. Built in every image build from the same commit (image/Containerfile),
# never published: its version is the image's, and its sources are this
# repository. Build it with
#   rpmbuild -bb --define "image_version VERSION" --define "image_revision COMMIT" \
#     --define "fedora_release VERSION-RELEASE" --define "systemd_boot VERSION-RELEASE" \
#     --define "signed_dir SIGNED" --define "source_dir SYSTEM" system.spec
# where fedora_release is that of the image's fedora-release-common, and SIGNED
# holds systemd-bootx64.efi.signed, signed from systemd-boot-unsigned at
# version systemd_boot, and enroll-this-key.cer, the certificate that signed it.
# Only these signed and public files reach the package; the key stays in the
# build (image/Containerfile). Requires with a macro are left out of the list
# that the image build installs from.

Name:           system
Version:        %{image_version}
Release:        1
Summary:        ShapeBit's system: updates, boot, login screen, and settings
# The font (usr/share/fonts/instrument-sans) is under the SIL Open Font License.
License:        LicenseRef-PolyForm-Shield-1.0.0 AND OFL-1.1
URL:            https://github.com/shapebit-software/os
# Marks ShapeBit's own packages, whose sources are this repository (scripts/release/sources.py).
Vendor:         ShapeBit
BuildArch:      noarch
BuildRequires:  plymouth-theme-spinner
Requires:       release = %{version}-%{release}

# The base image ships only GRUB; bootc installs systemd-boot from this package,
# and the *.signed copy in it when present: this package's, signed from
# exactly that version.
Requires:       systemd-boot-unsigned
Requires:       systemd-boot-unsigned = %{systemd_boot}
# The base image has only the C locale; the langpacks add the locales that the
# installer offers.
Requires:       glibc-all-langpacks
# SDDM and Plymouth need the system's logos; generic-logos provides them, since
# Fedora's logos are its trademarks, which a system made from Fedora may not carry
# (https://fedoraproject.org/wiki/Legal:Trademark_guidelines). Installed with
# them, it keeps dnf from choosing fedora-logos.
Requires:       generic-logos
# SDDM is the login screen; it draws with Mesa, and Fedora's presets enable
# sddm.service. Its greeter runs in Hyprland, installed with the desktop
# (usr/lib/sddm/compositor.lua). SDDM needs a package that provides a
# greeter display server; sddm-wayland-generic is the smallest, and brings
# Weston, which the greeter no longer uses.
Requires:       sddm
Requires:       sddm-wayland-generic
Requires:       mesa-dri-drivers
# The boot splash: ShapeBit's theme takes its images from Fedora's spinner
# theme, by links that this package makes.
Requires:       plymouth-theme-spinner
# Applications come from Flatpak, with Flathub's remote
# (usr/share/flatpak/remotes.d/flathub.flatpakrepo, as Flathub
# publishes it), which Flatpak adds by itself the first time it runs; its
# environment generators put the applications in the session's Apps.
# desktop-file-utils lets Flatpak record which applications open which types.
Requires:       flatpak
Requires:       desktop-file-utils
# Files (Nautilus) and Terminal (Ptyxis), the built-in apps that are not
# Flatpaks: GNOME publishes no Flatpak of Nautilus, and a terminal belongs
# outside a sandbox, on the system and its Distrobox containers, which Ptyxis
# opens too. They update and roll back with the OS. The other apps are
# recommended in Welcome and installed from Flathub. Where two apps open the
# same type, the desktop's default is in
# usr/share/applications/shapebit-mimeapps.list. Nautilus's
# thumbnailers draw the previews of images and videos.
Requires:       nautilus
Requires:       ptyxis
Requires:       glycin-thumbnailer
Requires:       gst-thumbnailers
# rsync is how tmt reaches a guest: without it, tmt would build a derived image
# and test that instead of this one. Nothing built in replaces it.
Requires:       rsync
# Distrobox, for development tools in containers (Podman is in the base
# image); this package sets its default image.
Requires:       distrobox


%description
ShapeBit's system: its updates (os-update), boot (kernel arguments, the
splash, the EFI shim on the disk), login screen, colors and font, and the
settings of systemd, dnf, Flatpak, polkit and SDDM.

%package -n release
Summary:        ShapeBit's identity: os-release and ShapeBit's license
License:        LicenseRef-PolyForm-Shield-1.0.0
# In place of Fedora's identity, the one package with /usr/lib/os-release:
# fedora-release-common, which the image keeps, asks for an identity at its
# own version.
Provides:       fedora-release-identity = %{fedora_release}
Conflicts:      fedora-release-identity-basic

%description -n release
ShapeBit's /usr/lib/os-release, with the image's version and the commit it is
built from, and ShapeBit's license.

%install
cp -a %{source_dir}/usr %{buildroot}/
printf 'IMAGE_VERSION=%s\nIMAGE_REVISION=%s\n' %{image_version} %{image_revision} >>%{buildroot}/usr/lib/os-release
# New Distrobox containers start from Fedora's toolbox image of this
# Fedora version, rather than its latest.
install -d %{buildroot}/usr/share/distrobox
echo 'container_image_default="registry.fedoraproject.org/fedora-toolbox:%{fedora}"' \
  >%{buildroot}/usr/share/distrobox/distrobox.conf
# The boot splash takes the spinner theme's images, except its watermark.
for image in /usr/share/plymouth/themes/spinner/*.png; do
  name=$(basename "$image")
  [ "$name" = watermark.png ] || ln -s "../spinner/$name" %{buildroot}/usr/share/plymouth/themes/boot/"$name"
done
# systemd-boot, signed with ShapeBit's key, and the certificate that the person
# enrolls in shim's MOK manager (usr/libexec/esp-shim).
install -Dm644 %{signed_dir}/systemd-bootx64.efi.signed %{buildroot}/usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed
install -Dm644 %{signed_dir}/enroll-this-key.cer %{buildroot}/usr/share/secureboot/enroll-this-key.cer
# Every other file it installs is this package's.
(cd %{buildroot} && find . ! -type d | sed 's|^\.||' |
  grep -vx -e /usr/lib/os-release -e /usr/share/licenses/shapebit/LICENSE) >files

%files -f files

%files -n release
/usr/lib/os-release
%dir /usr/share/licenses/shapebit
/usr/share/licenses/shapebit/LICENSE
