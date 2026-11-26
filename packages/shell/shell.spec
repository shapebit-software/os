# The shell: bars, dock, panels, Settings, notifications, and the lock screen. See ../package.macros.
%{load:%{packages}/package.macros}

Name:           shapebit-shell
Version:        %{image_version}
Release:        %{shapebit_release}
Summary:        The shell: bars, dock, panels, Settings, notifications, and the lock screen
License:        %{shapebit_program} AND %{shapebit_config}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make
# The shell, and its colors (the QML module Colors).
Requires:       quickshell
Requires:       shapebit-colors = %{version}-%{release}
# Idle time, the lock screen, and sleep (services/Idle.qml).
Requires:       hypridle
# The clipboard, kept after the application it came from closes (services/Clipboard.qml).
Requires:       clipman
Requires:       wl-clipboard
# The display's brightness and the power profile.
Requires:       brightnessctl
Requires:       power-profiles-daemon
# Battery state (services/Battery.qml).
Requires:       upower
# The shell's monospace font.
Requires:       jetbrains-mono-fonts

%description
The Quickshell shell: the system bar and the dock with their panels,
Settings, notifications, the window switcher, the capture overlay, and the
lock screen. See README.md.

%install
%shapebit_install shell

%files -f files
