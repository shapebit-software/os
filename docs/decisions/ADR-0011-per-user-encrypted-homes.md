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
