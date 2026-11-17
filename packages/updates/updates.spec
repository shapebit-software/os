# Updates: os-update, its timer, and who may run it. See ../package.macros.
%{load:%{packages}/package.macros}

Name:           shapebit-updates
Version:        %{image_version}
Release:        %{shapebit_release}
Summary:        Updates: os-update, its timer, and who may run it
License:        %{shapebit_license}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make

%description
os-update checks for and stages system updates with bootc, on a timer and
when the person asks.

%install
%shapebit_install updates

%files -f files
