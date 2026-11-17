# The installer: its interface, backend, command-line client, units, and what it
# runs on, each with the reason for it. Built in every installer medium build
# from the same commit (image/Containerfile.installer), never published: its
# version is the image's, and its sources are this repository. Build it with
#   rpmbuild -bb --define "image_version VERSION" --define "source_dir INSTALLER" installer.spec

# The sources are outside rpmbuild's tree, so there is nothing for a debuginfo
# package to point to; the binaries are stripped as usual.
%global debug_package %{nil}
%global _vpath_srcdir %{source_dir}

Name:           installer
Version:        %{image_version}
Release:        1
Summary:        ShapeBit's installer
License:        LicenseRef-PolyForm-Shield-1.0.0
URL:            https://github.com/shapebit-software/os
# Marks ShapeBit's own packages, whose sources are this repository (scripts/release/sources.py).
Vendor:         ShapeBit
BuildRequires:  cmake
BuildRequires:  ninja-build
BuildRequires:  gcc-c++
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qtdeclarative-devel
BuildRequires:  libxkbcommon-devel

# cage shows the installer full screen; nothing else of a desktop is needed.
Requires:       cage
# The interface's Qt modules, Wayland platform, and GPU drivers, which rpm's
# library dependencies do not name: Qt loads them as plugins.
Requires:       qt6-qtbase-gui
Requires:       qt6-qtdeclarative
Requires:       qt6-qtwayland
Requires:       mesa-dri-drivers
# The interface's fonts.
Requires:       google-noto-sans-fonts
Requires:       google-noto-sans-mono-fonts

%description
ShapeBit's installer: the full-screen interface, the backend that installs the
system with bootc, installerctl, and their units, presets, user, and D-Bus policy.

%build
%cmake -G Ninja
%cmake_build

%install
%cmake_install
# Every file it installs is the package's: the CMake install rules are the one list.
(cd %{buildroot} && find . ! -type d | sed 's|^\.||') > files

%files -f files
