#!/usr/bin/env bash
# Write the dnf repository of the external packages to SITE (README.md):
# repodata only, signed, for GitHub Pages; the RPMs stay release assets, at
# RPM_RELEASES/TAG/FILE. PACKAGES holds each release's RPMs in a directory
# named by its tag. Each Fedora version gets a binary and a source repository,
# fedora-VERSION-x86_64 and fedora-VERSION-source. RPM_SIGNING_KEY is the
# armored private key that signs each repomd.xml; dnf checks the signature with
# RPM_PUBLIC_KEY (packages/repositories/third-party.asc).
# Usage: rpm-repo.sh PACKAGES SITE (called by `make rpm-repo`).
set -euo pipefail
: "${ENGINE:?}" "${RPM_RELEASES:?}" "${RPM_PUBLIC_KEY:?}" "${RPM_SIGNING_KEY:?}"
packages=$(realpath "$1")
site=$(realpath -m "$2")
key=$(realpath "$RPM_PUBLIC_KEY")
mkdir -p "$site"

$ENGINE run --rm -e RPM_SIGNING_KEY -e "RPM_RELEASES=$RPM_RELEASES" -e "OWNER=$(id -u):$(id -g)" \
  -v "$packages:/packages:ro,z" -v "$site:/site:z" -v "$key:/third-party.asc:ro,z" \
  registry.fedoraproject.org/fedora:latest bash -euo pipefail -c '
dnf -y -q install createrepo_c gnupg2 >/dev/null
export GNUPGHOME=$(mktemp -d)
gpg --batch --quiet --import <<<"$RPM_SIGNING_KEY"
# The private key must be the one whose public key the image trusts.
gpg --batch --quiet --import /third-party.asc
signing=$(gpg --with-colons --list-secret-keys | awk -F: "/^fpr/ {print \$10; exit}")
trusted=$(gpg --with-colons --show-keys /third-party.asc | awk -F: "/^fpr/ {print \$10; exit}")
test "$signing" = "$trusted" || { echo "error: RPM_SIGNING_KEY is not the key of RPM_PUBLIC_KEY" >&2; exit 1; }
rm -rf /site/fedora-* && mkdir -p /tmp/repos
shopt -s nullglob
for rpm in /packages/*/*.rpm; do
  tag=$(basename "$(dirname "$rpm")")
  version=$(rpm -qp --qf "%{RELEASE}" "$rpm" | grep -o "fc[0-9]*$" | tr -d fc)
  case $rpm in *.src.rpm) repo=fedora-$version-source ;; *) repo=fedora-$version-x86_64 ;; esac
  mkdir -p "/tmp/repos/$repo/$tag"
  cp "$rpm" "/tmp/repos/$repo/$tag/"
done
for repo in /tmp/repos/*/; do
  name=$(basename "$repo")
  mkdir -p "/site/$name"
  createrepo_c --quiet --baseurl "$RPM_RELEASES/" --outputdir "/site/$name" "$repo"
  gpg --batch --yes --detach-sign --armor "/site/$name/repodata/repomd.xml"
done
cp /third-party.asc /site/RPM-GPG-KEY
chown -R "$OWNER" /site
'
find "$site" -name repomd.xml
