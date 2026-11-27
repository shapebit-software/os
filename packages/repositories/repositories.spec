# Repositories: where packages come from, and dnf's settings. See packaging's package.macros.
%{load:%{shapebit_macros}}

Name:           shapebit-repositories
Version:        %{shapebit_version}
Release:        %{shapebit_release}
Summary:        Repositories: where packages come from, and dnf's settings
License:        %{shapebit_config}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make

%description
The repositories that packages come from beside Fedora's, turned off on
installed systems, with ShapeBit's key; and dnf's settings.

%install
%shapebit_install repositories

%files -f files
