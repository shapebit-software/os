# Splash: the boot splash, and its hand-off to the login screen. See ../package.macros.
%{load:%{packages}/package.macros}

Name:           shapebit-splash
Version:        %{image_version}
Release:        %{shapebit_release}
Summary:        Splash: the boot splash, and its hand-off to the login screen
License:        %{shapebit_license}
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
