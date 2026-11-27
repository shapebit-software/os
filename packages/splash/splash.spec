# Splash: the boot splash, and its hand-off to the login screen. See packaging's package.macros.
%{load:%{shapebit_macros}}

Name:           shapebit-splash
Version:        %{shapebit_version}
Release:        %{shapebit_release}
Summary:        Splash: the boot splash, and its hand-off to the login screen
# Configuration; the watermark is the logo, under the brand's terms.
License:        %{shapebit_config} AND %{shapebit_brand}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make
BuildRequires:  plymouth-theme-spinner
# The theme takes its images from Fedora's spinner theme, by links that this
# package makes.
Requires:       plymouth-theme-spinner

%description
ShapeBit's boot splash (Plymouth), on the images of Fedora's spinner theme,
and its hand-off to the login screen without a black frame.

%install
%shapebit_install splash

%files -f files
