# Windows: the compositor, its layouts, workspaces, and shortcuts. See ../package.macros.
%{load:%{packages}/package.macros}

Name:           shapebit-windows
Version:        %{image_version}
Release:        %{shapebit_release}
Summary:        Windows: the compositor, its layouts, workspaces, and shortcuts
License:        %{shapebit_license}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make
# The compositor and the session. Hyprland, its dialogs, hypridle,
# xdg-desktop-portal-hyprland, and Quickshell come from a third-party COPR
# (repositories/hyprland.repo); Fedora has no Hyprland.
Requires:       hyprland
Requires:       uwsm
# Hyprland's own dialogs, such as when an application stops responding; it
# warns on the screen without them.
Requires:       hyprland-guiutils

%description
Hyprland, configured as ShapeBit's: its layouts, workspaces, and keyboard
shortcuts, the session that starts it, and applications without window
buttons of their own.

%install
%shapebit_install windows

%files -f files
