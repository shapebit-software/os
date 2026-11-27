# Colors: the system's colors, and the QML module made from them. See packaging's package.macros.
%{load:%{shapebit_macros}}

Name:           shapebit-colors
Version:        %{shapebit_version}
Release:        %{shapebit_release}
Summary:        Colors: the system's colors, and the QML module made from them
License:        %{shapebit_library}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make

%description
The system's colors (colors.toml), and Colors, the QML module made from them,
which the shell, the login screen, and the installer use.

%install
%shapebit_install colors

%files -f files
