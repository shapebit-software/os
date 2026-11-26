# Release: ShapeBit's identity, in place of Fedora's. See ../package.macros.
%{load:%{packages}/package.macros}

Name:           shapebit-release
Version:        %{image_version}
Release:        %{shapebit_release}
Summary:        ShapeBit's identity: os-release, with the image's version and commit
License:        %{shapebit_config}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make
# In place of Fedora's identity packages, whose release file, CPE, and software
# tags name Fedora, a trademark that a system made from Fedora may not carry
# (https://fedoraproject.org/wiki/Legal:Trademark_guidelines), as Fedora's
# generic-release does for remixes. It also takes over what they provide: the
# release that dnf reads as $releasever, the dist macros, and dnf's defaults.
Provides:       system-release
Provides:       system-release(%{fedora})
Provides:       system-release(releasever) = %{fedora}
Conflicts:      fedora-release
Conflicts:      fedora-release-common
Conflicts:      fedora-release-identity-basic
# What Fedora's identity package required: Fedora's repositories, at the
# image's release, and the systemd presets, which the installer medium's
# autoremove would otherwise take.
Requires:       fedora-repos(%{fedora})
Requires:       redhat-systemd-presets
# SDDM and Plymouth need the system's logos; generic-logos provides them, since
# Fedora's logos are its trademarks, which a system made from Fedora may not carry
# (https://fedoraproject.org/wiki/Legal:Trademark_guidelines). Installed with
# them, it keeps dnf from choosing fedora-logos.
Requires:       generic-logos

%description
ShapeBit's /usr/lib/os-release, with the image's version and the commit it is
built from, and the rest of a distribution's identity: its release file, CPE,
login banner, RPM dist macros, and dnf's defaults.

%install
%shapebit_install release

%files -f files
# Where programs add to the login banner, such as
# console-login-helper-messages-issuegen, which requires it; the build's own
# system has it, so the file list leaves it out.
%dir /etc/issue.d
