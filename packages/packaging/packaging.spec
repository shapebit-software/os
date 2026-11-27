# Packaging: how a ShapeBit package is built. See package.macros, its own.
%{load:%{shapebit_macros}}

Name:           shapebit-packaging
Version:        %{shapebit_version}
Release:        %{shapebit_release}
Summary:        Packaging: how a ShapeBit package is built
License:        %{shapebit_program}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make
# A package is built with rpmbuild and its Makefile; Rust programs' crates are
# listed by crates.py.
Requires:       make
Requires:       rpm-build
Requires:       python3

%description
How a ShapeBit package is built, for a package outside this repository: the
macros that every spec loads (package.macros), what every feature's Makefile
includes (package.mk, and cargo.mk for Rust programs, with crates.py), the
rpmlint findings that are accepted, and the texts of ShapeBit's licenses that
packages install. No OS image has it.

%install
%shapebit_install packaging

%files -f files
