#!/usr/bin/env bash
# Installs a tree's features into this running ShapeBit, as root, for
# `make sync` (development/sync.py, development/README.md): reads from stdin a
# tar of one folder per feature, each holding that feature's /usr and the
# features it requires (`requires`); makes each feature whose files differ a
# system extension in /run/extensions, which systemd-sysext lays over /usr
# until the next boot, or until `make unsync` (SYNC_RESET=1) takes them away;
# and refreshes the running units of those features and of the features that
# require them: each reloads, if it says how (ExecReload=), or restarts; a unit
# that a feature only extends, with a drop-in, only reloads.
# In the simulator (development/simulator), which has neither systemd nor
# system extensions, it copies the files in and runs the user units' reload
# commands itself.
# SYNC_PACKAGES, if set, names the only features it lays over /usr or takes away.
# Usage: [SYNC_RESET=1] [SYNC_PACKAGES=...] sync-apply.sh <features.tar (run by
# sync.py on the machine, through SSH or the host's engine).
set -euo pipefail
trap 'echo "error: sync-apply.sh: line $LINENO failed" >&2' ERR

# The simulator's session writes its settings here (simulator/session.sh).
simulator=/run/simulator
. /usr/lib/os-release
[ -e $simulator ] || [ "$ID" = shapebit ] ||
  { echo "error: this is $PRETTY_NAME, not ShapeBit; nothing was changed" >&2; exit 1; }

# bootc usroverlay's writable /usr, of an older make sync, would hide the extensions.
[ -e $simulator ] || [ "$(findmnt -n -o SOURCE /usr)" != transient ] ||
  { echo "error: /usr has a writable layer (bootc usroverlay); restart the machine first" >&2; exit 1; }
extensions=/run/extensions

tree=$(mktemp -d)
trap 'rm -rf "$tree"' EXIT
tar -x --no-same-owner -C "$tree"

# Whether FEATURE's files differ from those installed: content and links.
# The image's os-release, which names the extensions' OS, stays the image's.
differs() {
  local path
  while IFS= read -r -d '' path; do
    if [ -L "$tree/$1/$path" ]; then
      [ "$(readlink "$tree/$1/$path")" = "$(readlink "/$path" 2>/dev/null)" ] || return 0
    else
      cmp -s "$tree/$1/$path" "/$path" || return 0
    fi
  done < <(cd "$tree/$1" && find usr ! -type d ! -path usr/lib/os-release -print0)
  return 1
}

# Makes FEATURE's files the system extension of its name: for this OS (ID),
# with the labels that the policy gives the files' paths in /usr, as the
# image's have.
extend() {
  local extension=$extensions/$1 policy
  rm -rf "$extension"
  mkdir -p "$extension/usr/lib/extension-release.d"
  cp -dR --preserve=mode,timestamps "$tree/$1/usr" "$extension"
  rm -f "$extension/usr/lib/os-release"
  echo "ID=$ID" >"$extension/usr/lib/extension-release.d/extension-release.$1"
  if selinuxenabled; then
    policy=$(. /etc/selinux/config && echo "$SELINUXTYPE")
    setfiles -F -r "$extension" "/etc/selinux/$policy/contexts/files/file_contexts" "$extension/usr"
  fi
}

# The services of FEATURE in systemd's DIRECTORY (system or user), as patterns
# that match a template's instances too: its own (KIND service), or those
# that its drop-ins extend (KIND service.d), such as the compositor's.
units() {
  local path unit
  for path in "$tree/$1/usr/lib/systemd/$2"/*."$3"; do
    [ -e "$path" ] || continue
    unit=$(basename "$path" .d)
    echo "${unit/@./@*.}"
  done
}

# Refreshes FEATURE's running services through SYSTEMCTL (its command and
# options): its own reload, or else restart; those it only extends only
# reload, if they can, as restarting one, such as the login screen or
# systemd-homed, would end people's sessions.
refresh_units() {
  local feature=$1 directory=$2 unit own extended
  shift 2
  mapfile -t own < <(units "$feature" "$directory" service)
  [ ${#own[@]} -eq 0 ] || "$@" try-reload-or-restart "${own[@]}"
  mapfile -t extended < <(units "$feature" "$directory" service.d)
  [ ${#extended[@]} -gt 0 ] || return 0
  while read -r unit _; do
    [ "$("$@" show -p CanReload --value "$unit")" != yes ] || "$@" reload "$unit"
  done < <("$@" list-units --state=active --plain --no-legend "${extended[@]}")
}

# The features changed but not yet refreshed, by an earlier run that failed
# on the way, and those changed now; until the next boot. Changed are those
# whose files differ, or, for make unsync, those with an extension.
pending=/run/sync-pending
changed=()
[ ! -e $pending ] || mapfile -t changed <$pending
for dir in "$tree"/*/; do
  feature=$(basename "$dir")
  [ -z "${SYNC_PACKAGES:-}" ] || [[ " $SYNC_PACKAGES " = *" $feature "* ]] || continue
  if [ "${SYNC_RESET:-}" = 1 ]; then
    [ -d "$extensions/$feature" ] || continue
  else
    differs "$feature" || continue
  fi
  [[ " ${changed[*]} " = *" $feature "* ]] || changed+=("$feature")
  printf '%s\n' "${changed[@]}" >$pending
  if [ -e $simulator ]; then
    cp -dR --preserve=mode,timestamps "$dir/usr" /
  elif [ "${SYNC_RESET:-}" = 1 ]; then
    rm -rf "${extensions:?}/$feature"
  else
    extend "$feature"
  fi
done
if [ ${#changed[@]} -eq 0 ]; then
  echo "Nothing changed"
  exit 0
fi
echo "Changed: ${changed[*]}"
[ -e $simulator ] || systemd-sysext refresh

# Those, and the features that require one of them, such as the shell, which
# imports Colors.
refresh=("${changed[@]}")
for dir in "$tree"/*/; do
  feature=$(basename "$dir")
  [[ " ${refresh[*]} " != *" $feature "* ]] || continue
  if grep -qxF -f <(printf '%s\n' "${changed[@]}") "$dir/requires"; then
    refresh+=("$feature")
  fi
done

if [ -e $simulator ]; then
  # Its session's settings: SIMULATOR_USER, and the environment its commands need.
  . $simulator
  shopt -s nullglob
  for feature in "${refresh[@]}"; do
    files=("$tree/$feature/usr/lib/systemd/user"/*.service "$tree/$feature/usr/lib/systemd/user"/*.service.d/*.conf)
    [ ${#files[@]} -gt 0 ] || continue
    sed -n 's/^ExecReload=[-@:+!]*//p' "${files[@]}" | while IFS= read -r line; do
      setpriv --reuid="$SIMULATOR_USER" --regid="$SIMULATOR_GROUP" --clear-groups \
        env HOME="$HOME" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" bash -c "$line" >/dev/null || true
    done
  done
  rm -f $pending
  exit 0
fi

systemctl daemon-reload
for feature in "${refresh[@]}"; do
  refresh_units "$feature" system systemctl
done

# Each person's session, but the greeter's: a system user's.
while read -r uid user _; do
  [ "$uid" -ge 1000 ] || continue
  systemctl --user -M "$user@" daemon-reload
  for feature in "${refresh[@]}"; do
    refresh_units "$feature" user systemctl --user -M "$user@"
  done
done < <(loginctl list-users --no-legend)
rm -f $pending
