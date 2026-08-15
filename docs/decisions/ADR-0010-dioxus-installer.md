# ADR-0010: Dioxus as the ShapeBit OS Installer Frontend

**Status:** Accepted
**Date:** 2026-08-04
**Last updated:** 2026-08-12

## Context

The first custom ShapeBit OS component under development is an installer written in Dioxus. Installation operations require a privileged execution layer independent of the interface.

## Decision

The installer frontend will be developed in Dioxus.

```text
Dioxus UI
→ Installer Backend API
→ storage, bootc, systemd-boot, users, and configuration
```

The UI does not perform operations directly as root.

The shared installation plan contains declarative policy but no passwords,
recovery keys, or derived secrets. Secret enrollment uses a separate,
short-lived channel to the privileged backend and is excluded from transaction
logs. ADR-0035 defines the minimal ordinary protocol and plan. ADR-0036 defines
the one-shot secret channel.

This ADR selects the frontend technology and privilege boundary. Storage,
encryption, boot, and account policy remain owned by their respective ADRs.

## Positive consequences

- preservation of existing work;
- Rust and shared data models;
- a distinct product identity;
- UI testing without destroying disks;
- possibility of reusing components in onboarding and recovery.

## Negative consequences

- a separate backend to maintain;
- need to validate the Dioxus renderer in a minimal image;
- the graphical installer precedes the complete custom desktop environment;
- additional accessibility and error-path testing.

## Related decisions

- [ADR-0003](ADR-0003-btrfs-system-state.md)
- [ADR-0011](ADR-0011-per-user-encrypted-homes.md)
- [ADR-0012](ADR-0012-encrypted-system-volume.md)
- [ADR-0013](ADR-0013-boot-trust-and-tpm-policy.md)
- [ADR-0035](ADR-0035-minimal-installer-protocol.md)
- [ADR-0036](ADR-0036-one-shot-installer-secret-channel.md)
