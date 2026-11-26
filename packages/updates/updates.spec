# Updates: os-update, its timer, who may run it, and which updates it accepts.
# See ../package.macros.
%{load:%{packages}/package.macros}

Name:           shapebit-updates
Version:        %{image_version}
Release:        %{shapebit_release}
Summary:        Updates: os-update, its timer, and which updates it accepts
License:        %{shapebit_program} AND %{shapebit_config}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make

%description
os-update checks for and stages system updates with bootc, on a timer and
when the person asks; the system accepts only updates signed with ShapeBit's
release image key.

%install
%shapebit_install updates
sed -i 's|^/etc/containers/policy.json$|%%config(noreplace) &|' files

%files -f files
