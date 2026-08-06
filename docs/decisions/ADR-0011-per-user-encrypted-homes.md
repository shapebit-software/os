# ADR-0011: Per-User Encrypted Homes

**Status:** Accepted

**Date:** 2026-08-05

## Context

Each human user's home data must remain encrypted while that user is logged
out. Startup must not ask for one password to unlock storage and then ask for
the same password again to log in.

ShapeBit OS also plans to replace the initial TTY or conventional display
manager with a custom login screen. Storage encryption must therefore be tied
to the system authentication boundary, not to a particular login UI.

## Decision

- Human accounts use `systemd-homed` with one LUKS2 home container per user.
- The OS boots to a login surface without prompting for a user's home password.
- The user supplies one password through the PAM login conversation.
- `pam_systemd_home` uses that credential both to authenticate the user and to
  unlock and activate the user's home.
- The session starts only after the home is mounted successfully.
- The home is deactivated after the user's last session ends.
- Password changes must update the authentication credential and the LUKS2 key
  together through the supported PAM/systemd-homed path.
- Every user receives a separate recovery key during account creation. ShapeBit
  does not escrow the password or recovery key.
- System and service accounts are not managed by `systemd-homed`.

The future ShapeBit login screen will act as a PAM client. It must not implement
password verification, LUKS key derivation, or home mounting itself.

Inactive home-container files are persistent device state, initially stored
under `/var/lib/systemd/home/`. The system volume protects those files at the
physical-disk layer, but the separate per-user LUKS2 layer remains the authority
for access to an inactive home.

Each LUKS2 home uses Btrfs internally. Homes draw capacity from the protected
dynamic pool defined by ADR-0016 rather than fixed per-user partitions.

## Suspend authentication

ShapeBit exposes one user-facing **Require authentication after suspend**
setting, enabled by default.

Normal suspend remains the default laptop behavior; closing the lid does not
power off the device by default. Hibernation remains separately deferred.

When enabled, suspend locks both the desktop session and the active
`systemd-homed` home. The home key is removed from memory, access to the home is
suspended, and one authentication interaction restores both home access and the
session.

When disabled, both locks remain inactive so resume returns directly to the
session. The settings UI must warn that the active home key and session state
remain available in memory and that the full physical-access claim applies only
to a powered-off device. A future managed-device policy may force the setting
on.

## Secret handling

Account and storage policy may appear in `InstallationPlan`, but passwords and
recovery keys may not. Secrets use a separate short-lived channel, must not be
written to transaction logs, and must be cleared from memory as soon as the
authentication or enrollment operation completes.

## Consequences

- Each user's data remains unavailable while their home is inactive.
- Multiple users can unlock independent homes without a shared disk password.
- A forgotten password requires the user's recovery key or another previously
  enrolled credential; an administrator cannot bypass the encryption.
- Root can access a user's files while that home is active, so this protects
  data at rest rather than against a compromised running system.
- Login, logout, password change, recovery, backup, concurrent-session,
  suspend, and low-space behavior require integration tests.
- `/var` and other device state are protected by the TPM2-unlocked system
  volume defined in [ADR-0012](ADR-0012-encrypted-system-volume.md), without a
  routine second password prompt during normal startup.

## Boundaries

This ADR owns human-user home activation, recovery, filesystem choice, and
suspend authentication behavior. It does not define system-volume unlock or
grant the device recovery key access to any user's home.

## Related decisions

- [ADR-0012](ADR-0012-encrypted-system-volume.md)
- [ADR-0016](ADR-0016-initial-installation-and-storage-profile.md)
