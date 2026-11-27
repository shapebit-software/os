# Extras: what is too large for the OS image, such as speech and language models. See packaging's package.macros.
%{load:%{shapebit_macros}}

Name:           shapebit-extras
Version:        %{shapebit_version}
Release:        %{shapebit_release}
Summary:        Extras: what is too large for the OS image, such as speech and language models
License:        %{shapebit_program} AND %{shapebit_config}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make

%description
Downloads what is too large for the OS image and not everyone needs, such as
speech and language models, into /var/lib/extras; their license texts are
installed before they are downloaded.

%install
%shapebit_install extras

%files -f files
