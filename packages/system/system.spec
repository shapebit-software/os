# The system: every feature of the installed system, at the image's version, as
# Fedora's environments group a desktop's packages. The image installs this
# package last, so that `rpm -q --requires shapebit-system` lists what the OS is
# made of, and dnf would refuse an image that lacks a feature. The installer
# is not here: it is only on the installer medium. See ../package.macros.
%{load:%{packages}/package.macros}

Name:           shapebit-system
Version:        %{image_version}
Release:        %{shapebit_release}
Summary:        ShapeBit's system: every feature of the installed system
License:        %{shapebit_program}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch

# Every feature, at this version (packages/; packages/test_units.py checks
# that the list is complete).
Requires:       shapebit-apps = %{version}-%{release}
Requires:       shapebit-assistant = %{version}-%{release}
Requires:       shapebit-boot = %{version}-%{release}
Requires:       shapebit-capture = %{version}-%{release}
Requires:       shapebit-colors = %{version}-%{release}
Requires:       shapebit-dictation = %{version}-%{release}
Requires:       shapebit-downloads = %{version}-%{release}
Requires:       shapebit-extras = %{version}-%{release}
Requires:       shapebit-font = %{version}-%{release}
Requires:       shapebit-homes = %{version}-%{release}
Requires:       shapebit-licenses = %{version}-%{release}
Requires:       shapebit-login = %{version}-%{release}
Requires:       shapebit-network = %{version}-%{release}
Requires:       shapebit-portal = %{version}-%{release}
Requires:       shapebit-release = %{version}-%{release}
Requires:       shapebit-repositories = %{version}-%{release}
Requires:       shapebit-screen-sharing = %{version}-%{release}
Requires:       shapebit-shell = %{version}-%{release}
Requires:       shapebit-sound = %{version}-%{release}
Requires:       shapebit-splash = %{version}-%{release}
Requires:       shapebit-updates = %{version}-%{release}
Requires:       shapebit-windows = %{version}-%{release}

# What the whole system needs, beyond any one feature.
# The base image has only the C locale; the langpacks add the locales that the
# installer offers.
Requires:       glibc-all-langpacks
# Git and Make, which developing ShapeBit needs on the computer it runs on;
# every other tool is in the development image (development/README.md).
Requires:       git-core
Requires:       make

%description
ShapeBit OS: every feature of the installed system, at the image's version.

%install
: >files
%shapebit_license_install

%files -f files
