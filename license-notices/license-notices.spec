# The license notices that some installed Fedora packages lack, taken from their
# exact source RPMs by license-notices.py, into /usr/share/licenses/<package>/.
# Built in every image build (image/Containerfile), where the packages they are
# for are installed, never published: its version is the image's, and its
# sources are this repository. Build it with
#   rpmbuild -bb --define "image_version VERSION" --define "source_dir LICENSE-NOTICES" \
#     --define "cache CACHE" license-notices.spec
# where CACHE keeps the downloaded source RPMs between builds.

Name:           license-notices
Version:        %{image_version}
Release:        1
Summary:        License notices that some installed packages lack
# Each notice is under the terms of the package whose folder holds it: the
# licenses of the installed packages that the rules are for.
License:        %(python3 %{source_dir}/license-notices.py --licenses)
URL:            https://github.com/shapebit-software/os
# Marks ShapeBit's own packages, whose sources are this repository (scripts/release/sources.py).
Vendor:         ShapeBit
BuildArch:      noarch

%description
The license notices that some installed Fedora packages lack, from their exact
source RPMs. It shares each folder in /usr/share/licenses with the package the
notices are for.

%install
python3 %{source_dir}/license-notices.py %{buildroot} %{cache}
# Every notice is a license file; the folders are shared with their packages.
(cd %{buildroot} && find . -mindepth 4 -type d | sed 's|^\.|%%dir |'
 cd %{buildroot} && find . ! -type d | sed 's|^\.|%%license |') > files

%files -f files
