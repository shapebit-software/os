# Testing: the tests' own tools, and every tool the tests run with. See ../package.macros.
%{load:%{packages}/package.macros}

Name:           shapebit-testing
Version:        %{image_version}
Release:        %{shapebit_release}
Summary:        Testing: the tests' own tools, and every tool the tests run with
License:        %{shapebit_program}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make
BuildRequires:  python3
# Every level's tools; the development image installs them (image/Containerfile).
# Static: lint, and validate (rpmspec, Fedora's list of licenses, every file's
# license with reuse, Rust's formatter).
Requires:       python3-pyflakes
Requires:       license-validate
Requires:       reuse
Requires:       rustfmt
# Unit and integration: pytest, a bus of their own with fake system services,
# QML's test runner, ffmpeg for the recordings, and the ChatGPT tests' signed
# identities.
Requires:       python3-pytest
Requires:       dbus-daemon
Requires:       python3-dbusmock
Requires:       qt6-qtdeclarative-devel
Requires:       ffmpeg-free
Requires:       python3-jwt
Requires:       python3-cryptography
# System: the machines (QEMU with Secure Boot firmware and a software TPM; for
# make vm, in a window that the host's GPU renders for, through virglrenderer,
# which virtio-gpu-gl brings; it plays and records through the host's PipeWire
# and borrows its USB devices), SSH into them, Testinfra, and skopeo for the
# update registry.
Requires:       qemu-system-x86-core
Requires:       qemu-device-display-virtio-vga
Requires:       qemu-device-display-virtio-vga-gl
Requires:       qemu-device-display-virtio-gpu-gl
Requires:       qemu-img
Requires:       qemu-ui-gtk
Requires:       qemu-ui-opengl
Requires:       qemu-audio-pipewire
Requires:       qemu-device-usb-host
Requires:       edk2-ovmf
Requires:       swtpm
Requires:       openssh-clients
Requires:       python3-pytest-testinfra
Requires:       skopeo
# End to end: isotovideo, openQA's test engine, with Inline::Python for the
# Python modules.
Requires:       os-autoinst
Requires:       perl-Inline-Python

%description
The tests' own tools: the pytest plugin that holds every test to its level,
the fixtures that tests share, and the machines that the system tests run on;
and, as Requires, every tool the tests run with. Only the development image
has it; no OS image does.

%install
%shapebit_install testing

%files -f files
