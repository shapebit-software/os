# Portal: what applications ask of the desktop. See packaging's package.macros.
%{load:%{shapebit_macros}}

Name:           shapebit-portal
Version:        %{shapebit_version}
Release:        %{shapebit_release}
Summary:        Portal: what applications ask of the desktop, sharing the screen too
License:        %{shapebit_program} AND %{shapebit_config}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make
# The portal backend and the share picker run on GObject.
Requires:       python3-gobject
# Hyprland's portal, which portals.conf picks for global shortcuts and screen
# sharing; it asks the share picker what to share (xdph.conf).
Requires:       xdg-desktop-portal-hyprland

%description
The shell's portal backend, which xdg-desktop-portal asks for everything an
application needs from the desktop but global shortcuts and secrets: opening
and saving files, settings, questions, and sharing the screen, where
Hyprland's portal shares it and the share picker asks the person, in the
shell's capture overlay, what to share.

%install
%shapebit_install portal

%files -f files
