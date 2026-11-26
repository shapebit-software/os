#!/usr/bin/env bash
# Runs on the host before an editor opens the dev container (devcontainer.json):
# builds the development image, then writes .env for compose.yaml: this
# repository's path, KVM, and the groups of Docker's socket and of KVM, which
# the container's user joins, as development/dev.sh does.
set -euo pipefail
cd "$(dirname "$0")/.."
make dev-image ENGINE=docker
kvm=/dev/kvm
[ -e $kvm ] || kvm=/dev/null
docker_gid=$(stat -c %g /var/run/docker.sock)
kvm_gid=$docker_gid
[ $kvm = /dev/null ] || kvm_gid=$(stat -c %g $kvm)
cat >.devcontainer/.env <<EOF
WORKSPACE=$PWD
KVM=$kvm
DOCKER_GID=$docker_gid
KVM_GID=$kvm_gid
EOF
