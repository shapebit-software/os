# The desktop: compositor configuration, shell, session, helpers, and the
# license texts of the models that are extras. Built in every image build from
# the same commit (image/Containerfile), never published: its version is the
# image's, and its sources are this repository. Its dependencies are in
# desktop/packages. Build it with
#   rpmbuild -bb --define "image_version VERSION" --define "source_dir DESKTOP" desktop.spec

Name:           desktop
Version:        %{image_version}
Release:        1
Summary:        ShapeBit's desktop
License:        LicenseRef-PolyForm-Shield-1.0.0
URL:            https://github.com/shapebit-software/os
BuildArch:      noarch
BuildRequires:  make

%description
ShapeBit's desktop: Hyprland's configuration, the Quickshell shell with its
settings, the assistant, dictation, capture, downloads and the app center, their
helpers and user units, and the license texts of the models it downloads.

%install
make -C %{source_dir} install DESTDIR=%{buildroot}
# Every file it installs is the package's: desktop/Makefile is the one list.
(cd %{buildroot} && find . ! -type d | sed 's|^\.||') > files

%files -f files
%dir %{_datadir}/desktop
%dir %{_libexecdir}/desktop
