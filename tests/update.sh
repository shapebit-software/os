#!/usr/bin/env bash
# Update an installed system and roll it back, from the local registry
# (DEV_UPDATE_REF): build and publish IMAGE_VERSION.next and switch DISK to
# it, which stages it; os-update reports it ready without restarting; boot it
# and run tests/system.sh on it. Then publish IMAGE_VERSION.next2, which
# os-update downloads and stages by itself, as Check now does; boot it, and
# roll back to the build before. Leaves IMAGE and BUILD/image.tar at the
# newest build.
# Usage: update.sh (called by `make test-update`).
set -euo pipefail
: "${IMAGE_VERSION:?}" "${OWNER_NAME:?}" "${LOCALE:?}" "${KEYBOARD_LAYOUT:?}" "${TIME_ZONE:?}" "${DEV_UPDATE_REF:?}"
cd "$(dirname "$0")/.."

next=$IMAGE_VERSION.next
failed=0
reboot() { scripts/vm.sh --stop && scripts/vm.sh --background; }
expect() {
  if [[ $1 == "$2" ]]; then
    echo "ok   $3"
  else
    echo "FAIL $3 (got '$1', expected '$2')"
    failed=1
  fi
}
running_version() { scripts/ssh.sh '. /etc/os-release && echo "$IMAGE_VERSION"'; }
check_for_update() {
  scripts/ssh.sh systemctl start os-update@now.service
  scripts/ssh.sh "jq -r '.state + \" \" + .version' /run/os-update/status.json"
}
publish() {
  make --no-print-directory image IMAGE_VERSION="$1"
  scripts/publish.sh
}
trap 'scripts/vm.sh --stop' EXIT

# The VM follows the local registry, which serves plain HTTP. bootc switches
# only to an image other than the one running, so the new build goes first.
publish "$next"
scripts/vm.sh --background
scripts/ssh.sh "printf '[[registry]]\nlocation = \"%s\"\ninsecure = true\n' '${DEV_UPDATE_REF%%/*}' \
  >/etc/containers/registries.conf.d/50-dev-registry.conf && bootc switch --quiet '$DEV_UPDATE_REF'"
expect "$(check_for_update)" "ready $next" "os-update reports the staged build"
expect "$(running_version)" "$IMAGE_VERSION" "os-update does not restart"

reboot
expect "$(running_version)" "$next" "restarting boots the new build"
expect "$(check_for_update)" "current " "os-update finds no update for the running build"
scripts/ssh.sh "OWNER_NAME=$OWNER_NAME LOCALE=$LOCALE KEYBOARD_LAYOUT=$KEYBOARD_LAYOUT TIME_ZONE=$TIME_ZONE bash -s" \
  <tests/system.sh || failed=1

# A newer build, which only os-update downloads.
next2=$IMAGE_VERSION.next2
publish "$next2"
expect "$(check_for_update)" "ready $next2" "os-update downloads and stages a new build"
reboot
expect "$(running_version)" "$next2" "restarting boots the downloaded build"

scripts/ssh.sh bootc rollback
reboot
expect "$(running_version)" "$next" "rollback boots the previous build"

exit "$failed"
