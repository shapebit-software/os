# Network: joining Wi-Fi networks and VPNs from the shell. See ../package.macros.
%{load:%{packages}/package.macros}

Name:           shapebit-network
Version:        %{image_version}
Release:        %{shapebit_release}
Summary:        Network: joining Wi-Fi networks and VPNs from the shell
License:        %{shapebit_license}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make
# The connection agent talks to NetworkManager through GObject (libnm).
Requires:       python3-gobject

%description
The connection agent, which the shell's network panel talks to: it joins
Wi-Fi networks with the password the person types, through NetworkManager.

%install
%shapebit_install network

%files -f files
