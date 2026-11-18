# The installer: its interface, backend, command-line client, units, and what it
# runs on, each with the reason for it. Built in every installer medium build
# from the same commit (images/installer/Containerfile), never published: its version is
# the image's, and its sources are this repository. See ../package.macros.
%{load:%{packages}/package.macros}

# The sources are outside rpmbuild's tree, so there is nothing for a debuginfo
# package to point to; the binaries are stripped as usual.
%global debug_package %{nil}
%global _vpath_srcdir %{packages}/installer

Name:           shapebit-installer
Version:        %{image_version}
Release:        %{shapebit_release}
Summary:        ShapeBit's installer
License:        %{shapebit_license}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
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
system with bootc, installerctl, and their units, presets, user, and D-Bus
policy.

%build
# Qt's project setup gives installed binaries an $ORIGIN RUNPATH; in /usr/bin,
# with their libraries in the system's, they need none.
%cmake -G Ninja -DCMAKE_SKIP_INSTALL_RPATH=ON
%cmake_build

%install
%cmake_install
# Every file it installs is the package's: the CMake install rules are the one list.
(cd %{buildroot} && find . ! -type d | sed 's|^\.||') > files
%shapebit_license_install

%files -f files
