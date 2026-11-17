# Screen sharing: what to share, asked in the shell. See ../package.macros.
%{load:%{packages}/package.macros}

Name:           shapebit-screen-sharing
Version:        %{image_version}
Release:        %{shapebit_release}
Summary:        Screen sharing: what to share, asked in the shell
License:        %{shapebit_license}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make
# Hyprland's portal shares the screen (xdph.conf); the share picker runs on GObject.
Requires:       xdg-desktop-portal-hyprland
Requires:       python3-gobject

%description
Hyprland's portal shares the screen; the share picker asks the person, in
the shell's capture overlay, what to share.

%install
%shapebit_install screen-sharing

%files -f files
