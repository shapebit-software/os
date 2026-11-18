# Boot: kernel arguments, the composefs root, systemd-boot, and the EFI shim. See ../package.macros.
# Build it with --define "systemd_boot VERSION-RELEASE" --define "signed_dir SIGNED",
# where SIGNED holds systemd-bootx64.efi.signed, signed from systemd-boot-unsigned at
# version systemd_boot, and enroll-this-key.cer, the certificate that signed it. Only
# these signed and public files reach the package; the key stays in the build
# (images/os/Containerfile).
%{load:%{packages}/package.macros}

Name:           shapebit-boot
Version:        %{image_version}
Release:        %{shapebit_release}
Summary:        Boot: kernel arguments, the composefs root, systemd-boot, and the EFI shim
License:        %{shapebit_license}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make
# The base image ships only GRUB; bootc installs systemd-boot from this package,
# and the *.signed copy in it when present: this package's, signed from exactly
# that version. Requires with a macro are left out of what the image build
# installs first (images/os/Containerfile).
Requires:       systemd-boot-unsigned
Requires:       systemd-boot-unsigned = %{systemd_boot}

%description
Kernel arguments, the composefs root, systemd-boot signed with ShapeBit's
key, the certificate that the person enrolls, and the EFI shim on the disk.

%install
%shapebit_install boot
# systemd-boot, signed with ShapeBit's key, and the certificate that the person
# enrolls in shim's MOK manager (esp-shim).
install -Dm644 %{signed_dir}/systemd-bootx64.efi.signed %{buildroot}/usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed
install -Dm644 %{signed_dir}/enroll-this-key.cer %{buildroot}/usr/share/secureboot/enroll-this-key.cer
echo /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed >>files
echo /usr/share/secureboot/enroll-this-key.cer >>files
echo '%%dir /usr/share/secureboot' >>files

%files -f files
