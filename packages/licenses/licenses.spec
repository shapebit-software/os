# Licenses: ShapeBit's license, Settings > Licenses, and the license notices
# that some installed Fedora packages lack, taken from their exact source RPMs
# by notices.py into /usr/share/licenses/<package>/. See ../package.macros.
# Built last in the image build (images/os/Containerfile), where the
# packages the notices are for are installed, with
#   --define "cache CACHE"
# where CACHE keeps the downloaded source RPMs between builds.
%{load:%{packages}/package.macros}

Name:           shapebit-licenses
Version:        %{image_version}
Release:        %{shapebit_release}
Summary:        Licenses: ShapeBit's license, Settings > Licenses, and the notices some packages lack
# ShapeBit's, for its license and the reader; each notice is under the terms of
# the package whose folder holds it: the licenses of the installed packages
# that notices.py's rules are for.
License:        %{shapebit_license} AND %(python3 %{packages}/licenses/notices.py --licenses)
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make

%description
ShapeBit's license; the reader of every component's license texts that
Settings > Licenses shows; and the license notices that some installed Fedora
packages lack, from their exact source RPMs. It shares each folder in
/usr/share/licenses with the package the notices are for.

%install
%shapebit_install licenses
python3 %{packages}/licenses/notices.py %{buildroot} %{cache}
# Every notice is a license file; the folders are shared with their packages.
(cd %{buildroot}/usr/share/licenses
 find . -mindepth 1 -maxdepth 1 -type d ! -name shapebit | sed 's|^\.|%%dir /usr/share/licenses|'
 find . -mindepth 2 -type d ! -path './shapebit*' | sed 's|^\.|%%dir /usr/share/licenses|'
 find . -type f ! -path './shapebit/*' | sed 's|^\.|%%license /usr/share/licenses|') >>files

%files -f files
