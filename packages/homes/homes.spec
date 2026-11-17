# Homes: each person's encrypted home (systemd-homed). See ../package.macros.
%{load:%{packages}/package.macros}

Name:           shapebit-homes
Version:        %{image_version}
Release:        %{shapebit_release}
Summary:        Homes: each person's encrypted home (systemd-homed)
License:        %{shapebit_license}
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
