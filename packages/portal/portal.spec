# Portal: what applications ask of the desktop. See ../package.macros.
%{load:%{packages}/package.macros}

Name:           shapebit-portal
Version:        %{image_version}
Release:        %{shapebit_release}
Summary:        Portal: what applications ask of the desktop
License:        %{shapebit_program} AND %{shapebit_config}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make
# The portal backend runs on GObject.
Requires:       python3-gobject
# Hyprland's portal, which portals.conf picks for global shortcuts and screen
# sharing (screen-sharing).
Requires:       xdg-desktop-portal-hyprland

%description
The shell's portal backend, which xdg-desktop-portal asks for everything an
application needs from the desktop but screen sharing, global shortcuts, and
secrets: opening and saving files, settings, and questions.

%install
%shapebit_install portal

%files -f files
