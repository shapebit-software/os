# Release: ShapeBit's identity, in place of Fedora's. See ../package.macros.
# Build it with --define "fedora_release VERSION-RELEASE", that of the image's
# fedora-release-common.
%{load:%{packages}/package.macros}

Name:           shapebit-release
Version:        %{image_version}
Release:        %{shapebit_release}
Summary:        ShapeBit's identity: os-release, with the image's version and commit
License:        %{shapebit_license}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make
# In place of Fedora's identity, the one package with /usr/lib/os-release:
# fedora-release-common, which the image keeps, asks for an identity at its
# own version.
Provides:       fedora-release-identity = %{fedora_release}
Conflicts:      fedora-release-identity-basic
# SDDM and Plymouth need the system's logos; generic-logos provides them, since
# Fedora's logos are its trademarks, which a system made from Fedora may not carry
# (https://fedoraproject.org/wiki/Legal:Trademark_guidelines). Installed with
# them, it keeps dnf from choosing fedora-logos.
Requires:       generic-logos

%description
ShapeBit's /usr/lib/os-release, with the image's version and the commit it is
built from.

%install
%shapebit_install release

%files -f files
