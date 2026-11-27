# Apps: Flathub, the built-in apps, and installing and updating apps. See packaging's package.macros.
%{load:%{shapebit_macros}}

Name:           shapebit-apps
Version:        %{shapebit_version}
Release:        %{shapebit_release}
Summary:        Apps: Flathub, the built-in apps, and installing and updating apps
License:        %{shapebit_program} AND %{shapebit_config}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make
# Applications come from Flatpak, with Flathub's remote (flathub.flatpakrepo,
# as Flathub publishes it), which Flatpak adds by itself the first time it runs;
# its environment generators put the applications in the session's Apps.
# desktop-file-utils lets Flatpak record which applications open which types.
Requires:       flatpak
Requires:       desktop-file-utils
# Files (Nautilus) and Terminal (Ptyxis), the built-in apps that are not
# Flatpaks: GNOME publishes no Flatpak of Nautilus, and a terminal belongs
# outside a sandbox, on the system and its Distrobox containers, which Ptyxis
# opens too. They update and roll back with the OS. The other apps are
# recommended in Welcome and installed from Flathub. Where two apps open the
# same type, the desktop's default is in shapebit-mimeapps.list. Nautilus's
# thumbnailers draw the previews of images and videos.
Requires:       nautilus
Requires:       ptyxis
Requires:       glycin-thumbnailer
Requires:       gst-thumbnailers
# Distrobox, for development tools in containers (Podman is in the base
# image); this package sets its default image.
Requires:       distrobox
# The app installer (app-install, app-catalog) talks to Flatpak through GObject.
Requires:       python3-gobject

%description
Applications come from Flatpak, with Flathub's remote, and Settings > Apps
installs, updates, and removes them in the person's own installation. Files
and Terminal are the built-in apps that are not Flatpaks; the desktop's
default apps, and Distrobox's image.

%install
%shapebit_install apps

%files -f files
