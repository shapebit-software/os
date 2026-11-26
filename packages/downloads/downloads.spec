# Downloads: the one queue of what the desktop downloads and installs. See ../package.macros.
%{load:%{packages}/package.macros}

Name:           shapebit-downloads
Version:        %{image_version}
Release:        %{shapebit_release}
Summary:        Downloads: the one queue of what the desktop downloads and installs
License:        %{shapebit_program} AND %{shapebit_config}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make

%description
The one queue of apps, browsers, and extras that the desktop downloads and
installs, which goes on after a logout or restart.

%install
%shapebit_install downloads

%files -f files
