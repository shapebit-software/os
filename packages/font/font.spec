# Font: Instrument Sans, the system's font. See ../package.macros.
%{load:%{packages}/package.macros}

Name:           shapebit-font
Version:        %{image_version}
Release:        %{shapebit_release}
Summary:        Font: Instrument Sans, the system's font
# Instrument Sans, under the SIL Open Font License; nothing of ShapeBit's own.
License:        OFL-1.1
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make

%description
Instrument Sans, the system's font, with its license.

%install
%shapebit_install font
# The font's license is its %license.
sed -i 's|^/usr/share/licenses/|%%license /usr/share/licenses/|' files

%files -f files
