#!/usr/bin/env bash
# Prints what ShapeBit's packages need from Fedora and the repositories
# (packages/repositories/README.md), one package per line: what they run on
# (Requires), or with --build, what they build with (BuildRequires). ShapeBit's
# own are left out, and so are Requires with a macro, the specs' own, which
# are checked when the packages are installed. The specs are SPEC..., by
# default those of the OS image: the one at the top of each feature folder,
# but the installer's, which is only on the medium, and testing's, which only
# the development image has. With --check, fails on a
# package that no longer exists in FEDORA_VERSION or ShapeBit's repository,
# before an image build would find out; the query reads only metadata.
# Usage: requires.sh [--build] [SPEC...]   (called by the images' Containerfiles)
#        requires.sh --check                (called by make validate)
set -euo pipefail
cd "$(dirname "$0")"

field=Requires check=
case ${1:-} in
  --build) field=BuildRequires; shift ;;
  --check) check=1; shift ;;
esac
if (($# == 0)); then
  set -- $(ls ./*/*.spec | grep -v -e '^\./installer/' -e '^\./testing/')
fi

packages=$(sed -n "s/^$field: *//p" "$@" | grep -v -e '%{' -e '^shapebit-' | sort -u)
if [[ -z $check ]]; then
  echo "$packages"
  exit 0
fi

: "${FEDORA_VERSION:?}"
status=0
# Fedora's repositories, and the two that the foundation's build turns on
# (image/Containerfile, its foundation stage); metadata needs no signature check here.
repos=()
for repo in hyprland third-party; do
  url=$(sed -n 's/^baseurl=//p' "repositories/system/$repo.repo" | head -1)
  repos+=(--repofrompath="$repo,$url" --setopt="$repo.repo_gpgcheck=0")
done
for package in $packages; do
  if [[ -z $(dnf -q repoquery --releasever="$FEDORA_VERSION" --latest-limit=1 "${repos[@]}" \
    "$package" 2>/dev/null) ]]; then
    echo "error: $(grep -l "^$field: *$package\$" "$@" | paste -sd " "): no package $package" >&2
    status=1
  fi
done
exit "$status"
