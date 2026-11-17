#!/usr/bin/env bash
# Build one package of third-party/ in a Fedora container, into OUT: its binary and
# source RPMs (third-party/README.md). Its Sources are downloaded first and checked
# against the package's `sources` file; the build itself has no network.
# Usage: rpm-build.sh third-party/NAME OUT (called by `make rpm`).
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
dnf -y -q install rpm-build rpmdevtools dnf-plugins-core
mkdir -p ~/rpmbuild/SOURCES
spectool -g -C ~/rpmbuild/SOURCES /package/$name.spec
(cd ~/rpmbuild/SOURCES && sha256sum --quiet -c /package/sources)
dnf -y -q builddep /package/$name.spec
rpmbuild -br /package/$name.spec || test \$? -eq 11
shopt -s nullglob
for buildreqs in ~/rpmbuild/SRPMS/*.buildreqs.nosrc.rpm; do dnf -y -q builddep \"\$buildreqs\"; done
rm -rf ~/rpmbuild/SRPMS ~/rpmbuild/BUILD
"
$ENGINE commit "$container" "$prepared" >/dev/null
$ENGINE rm "$container" >/dev/null

$ENGINE run --rm --name "$container" --network none -v "$dir:/package:ro,z" -v "$out:/out:z" \
  -e "OWNER=$(id -u):$(id -g)" "$prepared" bash -euo pipefail -c "
rpmbuild -ba /package/$name.spec
cp ~/rpmbuild/RPMS/*/*.rpm ~/rpmbuild/SRPMS/*.src.rpm /out/
chown \"\$OWNER\" /out/*.rpm
"
$ENGINE rmi "$prepared" >/dev/null
ls "$out"
