# ShapeBit OS project status

**Bundle version:** 0.5  
**Consolidation date:** 2026-08-04  
**Phase:** architecture and first-prototype preparation

## Accepted decisions

- Fedora and bootc form the system base.
- The system is image-based and uses atomic deployments.
- systemd is the init system and service platform.
- systemd-boot and BLS are used from the first prototype.
- LUKS2 is mandatory default encryption for persistent data.
- Btrfs is the proposed filesystem for `/var` and `/home`.
- The first working system is console-only.
- Dioxus is the frontend for the custom installer.
- The installer UI is separated from the privileged backend.

## Current implementation goal

Build a minimal ShapeBit OS image that:

1. is built from `Containerfile`;
2. passes `bootc container lint`;
3. can be installed to a QEMU disk;
4. boots through UEFI and systemd-boot;
5. unlocks LUKS2;
6. mounts Btrfs;
7. starts systemd and a TTY;
8. allows console login;
9. preserves `/home` and `/var` across deployments.

## Next custom component

The Dioxus installer:

```text
installer/ui
→ installer/protocol
→ installer/backend
```

The first integration will use a mock/dry-run backend. Operations on a real disk will be added only after the `InstallationPlan` model has stabilized.

## Most important open decisions

- exact Fedora bootc base-image version;
- installer UI ↔ backend communication format;
- method for generating and updating UKIs;
- production Secure Boot and shim model;
- exact `/boot`, ESP, and encrypted Btrfs partition layout;
- boot-counting and acceptance health-check mechanism;
- form of independent recovery;
- Dioxus renderer for the minimal installer image.
