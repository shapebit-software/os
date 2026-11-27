# Network: joining Wi-Fi networks and VPNs from the shell. See ../package.macros.
%{load:%{packages}/package.macros}

# The sources are outside rpmbuild's tree, so there is nothing for a debuginfo
# package to point to; the binary is stripped as usual.
%global debug_package %{nil}

Name:           shapebit-network
Version:        %{image_version}
Release:        %{shapebit_release}
Summary:        Network: joining Wi-Fi networks and VPNs from the shell
# The connection agent, and the crates it is built from (../cargo.mk).
License:        %{shapebit_program} AND %(make -s -C %{packages}/network licenses 2>/dev/null)
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildRequires:  make
BuildRequires:  cargo
BuildRequires:  rust
# The crates of Cargo.toml: each crate's features that it turns on.
BuildRequires:  rust-async-channel+default-devel
BuildRequires:  rust-async-executor+default-devel
BuildRequires:  rust-async-io+default-devel
BuildRequires:  rust-futures-lite+default-devel
BuildRequires:  rust-serde+default-devel
BuildRequires:  rust-serde_json+default-devel
BuildRequires:  rust-zbus-devel
BuildRequires:  rust-zbus+default-rt-devel
BuildRequires:  rust-zbus+proxy-devel
BuildRequires:  rust-zbus+service-devel

%description
The connection agent, which the shell's network panel talks to: it joins
Wi-Fi networks with the password the person types, through NetworkManager,
and pairs Bluetooth devices, through BlueZ.

%install
%shapebit_install network

%files -f files
