# Login: the login screen, and the secrets it unlocks. See packaging's package.macros.
%{load:%{shapebit_macros}}

Name:           shapebit-login
Version:        %{shapebit_version}
Release:        %{shapebit_release}
Summary:        Login: the login screen, and the secrets it unlocks
License:        %{shapebit_program} AND %{shapebit_config}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make
# SDDM is the login screen; it draws with Mesa, and Fedora's presets enable
# sddm.service. Its greeter runs in Hyprland (compositor.lua). SDDM needs a
# package that provides a greeter display server; sddm-wayland-generic is the
# smallest, and brings Weston, which the greeter no longer uses.
Requires:       sddm
Requires:       sddm-wayland-generic
Requires:       mesa-dri-drivers
# Secrets (the Secret Service and its portal), unlocked by the login password:
# SDDM's PAM configuration calls pam_oo7 when it is installed.
Requires:       oo7-daemon
Requires:       oo7-portal
Requires:       pam_oo7

%description
The login screen: SDDM's settings, the compositor its greeter runs in, and
its theme; and the secrets that the login password unlocks.

%install
%shapebit_install login

%files -f files
