# Font: Instrument Sans, the system's font. See ../package.macros.
%{load:%{packages}/package.macros}

Name:           shapebit-font
Version:        %{image_version}
Release:        %{shapebit_release}
Summary:        Font: Instrument Sans, the system's font
License:        %{shapebit_license}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make

%description
Instrument Sans, the system's font, with its license.

%install
%shapebit_install font

%files -f files
