# Homes: each person's encrypted home (systemd-homed). See packaging's package.macros.
%{load:%{shapebit_macros}}

Name:           shapebit-homes
Version:        %{shapebit_version}
Release:        %{shapebit_release}
Summary:        Homes: each person's encrypted home (systemd-homed)
License:        %{shapebit_config}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make

%description
Each person's home is encrypted with their password (systemd-homed), on the
storage the installer chose.

%install
%shapebit_install homes

%files -f files
