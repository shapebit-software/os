# Licenses: ShapeBit's license, and Settings > Licenses. See ../package.macros.
%{load:%{packages}/package.macros}

Name:           shapebit-licenses
Version:        %{image_version}
Release:        %{shapebit_release}
Summary:        Licenses: ShapeBit's license, and Settings > Licenses
License:        %{shapebit_license}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make

%description
ShapeBit's license, and the reader of every component's license texts that
Settings > Licenses shows.

%install
%shapebit_install licenses

%files -f files
