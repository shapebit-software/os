#!/usr/bin/env bash
# Build one external package (a folder with its spec and a sources file, in the
# feature that needs it; README.md) in a Fedora container, into OUT: its binary
# and source RPMs. Its Sources are downloaded first and checked against the
# `sources` file, in Fedora's format (`SHA512 (FILE) = HASH`); its own files,
# such as patches, go beside them. The build itself has no network; rpmlint
# then checks the packages, with the findings that packaging's rpmlint.toml accepts.
# Usage: rpm-build.sh packages/FEATURE/external/NAME OUT (called by `make rpm`).
set -euo pipefail
: "${ENGINE:?}" "${FEDORA_VERSION:?}"
dir=$(realpath "$1")
out=$(realpath -m "$2")
name=$(basename "$dir")
mkdir -p "$out"

prepared=localhost/rpm-build-$name:prepared
container=rpm-build-$name
$ENGINE rm -f "$container" >/dev/null 2>&1 || true
trap '$ENGINE rm -f "$container" >/dev/null 2>&1 || true' EXIT

# Sources and build dependencies, with the network. %generate_buildrequires
# lists more of them once the sources are unpacked (rpmbuild -br).
$ENGINE run --name "$container" -v "$dir:/package:ro,z" \
  "registry.fedoraproject.org/fedora:$FEDORA_VERSION" bash -euo pipefail -c "
dnf -y -q install rpm-build rpmdevtools dnf-plugins-core rpmlint
mkdir -p ~/rpmbuild/SOURCES
cp -r /package/. ~/rpmbuild/SOURCES/
spectool -g -C ~/rpmbuild/SOURCES /package/$name.spec
(cd ~/rpmbuild/SOURCES && sha512sum --quiet -c /package/sources)
dnf -y -q builddep /package/$name.spec
rpmbuild -br /package/$name.spec || test \$? -eq 11
shopt -s nullglob
for buildreqs in ~/rpmbuild/SRPMS/*.buildreqs.nosrc.rpm; do dnf -y -q builddep \"\$buildreqs\"; done
rm -rf ~/rpmbuild/SRPMS ~/rpmbuild/BUILD
"
$ENGINE commit "$container" "$prepared" >/dev/null
$ENGINE rm "$container" >/dev/null

$ENGINE run --rm --name "$container" --network none -v "$dir:/package:ro,z" -v "$out:/out:z" \
  -v "$(realpath "$(dirname "$0")/../../packaging/data/rpmlint.toml"):/rpmlint.toml:ro,z" \
  -e "OWNER=$(id -u):$(id -g)" "$prepared" bash -euo pipefail -c "
rpmbuild -ba /package/$name.spec
rpmlint --config /rpmlint.toml ~/rpmbuild/RPMS/*/*.rpm ~/rpmbuild/SRPMS/*.src.rpm
cp ~/rpmbuild/RPMS/*/*.rpm ~/rpmbuild/SRPMS/*.src.rpm /out/
chown \"\$OWNER\" /out/*.rpm
"
$ENGINE rmi "$prepared" >/dev/null
ls "$out"
