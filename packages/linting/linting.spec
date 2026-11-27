# Linting: how ShapeBit's code is checked without running it. See packaging's package.macros.
%{load:%{shapebit_macros}}

Name:           shapebit-linting
Version:        %{shapebit_version}
Release:        %{shapebit_release}
Summary:        Linting: how ShapeBit's code is checked without running it
License:        %{shapebit_program}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make
# The checks: Git lists the files; pyflakes, rustfmt, and qmllint read them;
# reuse checks every file's license, and license-validate each spec's License.
Requires:       bash
Requires:       git-core
Requires:       python3-pyflakes
Requires:       rustfmt
Requires:       /usr/bin/qmllint-qt6
Requires:       reuse
Requires:       license-validate

%description
How ShapeBit's code is checked without running it: lint.sh, which checks every
shell, Python, and Rust file, Rust's formatting rules, and, as Requires, the
tools that check QML, every file's license, and each spec's License. No OS
image has it.

%install
%shapebit_install linting

%files -f files
