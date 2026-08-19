# ADR-0005: Separate Rollback, Backup, and Reset Operations

**Status:** Accepted
**Date:** 2026-08-04
**Last updated:** 2026-08-15

## Context

System rollback, data restoration, and device reset solve three different problems. Combining them creates a risk of data loss.

## Decision

- **Roll back**, while a candidate remains unaccepted, selects its previous
  accepted baseline and preserves compatible prepared host state and all homes.
- **Repair system** restores the current system and boot artifacts while
  preserving `/etc`, `/var`, and all homes.
- **Reset system** clears system configuration and device state while
  preserving the encrypted home containers.
- **Remove user** removes one account and securely discards only that user's
  home.
- **Erase device** removes all device state and every user home.
- A filesystem snapshot is never the sole backup.

### Reset and home rebinding

System reset preserves the encrypted containers plus a minimal, non-private
inventory containing the old public signing certificate or hash, account and
container identifiers, and previous role. It does not preserve the old local
`systemd-homed` private signing key or trust bindings.

The reset installation generates a new local signing key. The initial owner and
each additional user rebind their own home by proving possession of that home's
password or recovery key. The device recovery key never unlocks or rebinds a
user home.

### Erase outcomes

The UI offers two distinct outcomes:

- **Erase and reinstall ShapeBit** performs cryptographic erase and installs
  the latest compatible, non-revoked stable release;
- **Erase without reinstalling** performs the erase and leaves no installed
  operating system.

Standard erase destroys cryptographic access. A separately selected verified
hardware sanitize operation may be offered when the device reports reliable
support. Reinstallation obtains the image from the network by default and
accepts signed USB media as an offline fallback; ShapeBit does not reserve a
large local factory image. Repair may restore the currently accepted release,
but erase-and-reinstall does not reinstall a known revoked release.

### Authorization

| Action | Required authorization |
|---|---|
| diagnostics and boot-chain checks | none |
| rollback or repair | administrator credential or device recovery key |
| system reset | owner credential or device recovery key |
| recover or export one home | that user's credential or home recovery key |
| remove one user | owner credential plus explicit confirmation |
| erase device | owner credential or device recovery key plus explicit confirmation |

When initiated from the running system, privileged actions reauthenticate
through PAM. Destructive flows show the exact disk, require typed confirmation,
and verify adequate power before starting. Full erase destroys both device
state and every user-home container. No operation silently changes the meaning
of deployment rollback.

## Consequences

The recovery interface must clearly present the three separate operations and their effects.

## Related decisions

- [ADR-0040](ADR-0040-forward-only-migrations-and-trial-bounded-rollback.md)
  limits the guaranteed rollback window to the period before durable trial
  acceptance.
- [ADR-0007](ADR-0007-trial-boot-and-acceptance.md) owns deployment rollback.
- [ADR-0008](ADR-0008-independent-recovery.md) owns the recovery environment.
- [ADR-0011](ADR-0011-per-user-encrypted-homes.md) owns user-home encryption.
