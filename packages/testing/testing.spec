# Testing: the tests' own tools, and every tool the tests run with. See packaging's package.macros.
%{load:%{shapebit_macros}}

# The modules run from source, as in the tree: no bytecode, which rpm would
# compile after the install listed the package's files.
%global __brp_python_bytecompile %{nil}

Name:           shapebit-testing
Version:        %{shapebit_version}
Release:        %{shapebit_release}
Summary:        Testing: the tests' own tools, and every tool the tests run with
License:        %{shapebit_program}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make
BuildRequires:  python3
# The plugin, the integration tests' fixtures, and the fakes: pytest, and a bus
# of their own for dbusmock's made-up services; QML's test runner, ffmpeg for
# the recordings, and the ChatGPT tests' signed identities.
Requires:       python3-pytest
Requires:       dbus-daemon
Requires:       python3-dbusmock
Requires:       qt6-qtdeclarative-devel
Requires:       ffmpeg-free
Requires:       python3-jwt
Requires:       python3-cryptography

%description
The tests' own tools: the pytest plugin that holds every test to its level, the
fixtures and fakes that integration tests share, and changed.py, which says
what a change touches; and, as Requires, what unit and integration tests run
with. pytest loads the plugin by its entry point. No OS image has it.

%package machines
Summary:        Testing: the machines that the system tests run on
Requires:       %{name} = %{version}-%{release}
# QEMU with Secure Boot firmware and a software TPM; for make vm, in a window
# that the host's GPU renders for, through virglrenderer, which virtio-gpu-gl
# brings; it plays and records through the host's PipeWire and borrows its USB
# devices. SSH into the machines, Testinfra, and skopeo for the update registry.
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

%description machines
The machines that the system tests run on (machine.py), and the system tests'
fixtures (system.py), which reach a machine over SSH or a container of the
image through the engine.

%package e2e
Summary:        Testing: the end-to-end tests' harness, with openQA
Requires:       %{name}-machines = %{version}-%{release}
# isotovideo, openQA's test engine, with Inline::Python for the Python modules.
Requires:       os-autoinst
Requires:       perl-Inline-Python

%description e2e
The openQA harness of the end-to-end tests: main.pm, its helpers, the needles
that several features share, and run.py, which assembles each feature's
modules for a run.

%install
%shapebit_install testing
# The machines and the harness are the subpackages'.
grep -v -e '/testing/machine\.py$' -e '/testing/system\.py$' -e '/shapebit/testing/e2e' files >files.main
grep -e '/testing/machine\.py$' -e '/testing/system\.py$' files >files.machines
grep -e '/shapebit/testing/e2e' files >files.e2e

%files -f files.main

%files machines -f files.machines

%files e2e -f files.e2e
