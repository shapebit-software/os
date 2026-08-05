# 11. Installer and Hardware

**Status:** Proposed  
**Owner:** Installer / Core Platform  
**Last updated:** 2026-08-04  
**Related ADRs:** ADR-0010

## Direction

ShapeBit OS will have a custom installer written in Dioxus. It is the first custom product component intended for system integration.

Architecture:

```text
Dioxus Installer UI
        ↓
Installer Backend API
        ↓
storage / LUKS2 / Btrfs / bootc / systemd-boot / users
```

The frontend does not perform operations directly as root.

## Dioxus frontend

Responsible for disk selection, regional settings, user creation, encryption configuration, operation summaries, progress, and error messages.

## Installer backend

A separate privileged process performs:

```text
probe_hardware
plan_installation
validate_plan
partition_disk
create_luks
create_btrfs
create_subvolumes
install_bootc_image
install_systemd_boot
configure_recovery
create_user
configure_locale
verify_installation
finalize
```

The backend has an explicit state machine, transaction IDs, an operation log, dry-run support, and strict block-device validation.

## First stage

The installer does not initially need to run inside the custom desktop environment. The first version may run on a development host or in a dedicated test image.

First goal:

```text
Dioxus UI
→ select a virtual disk
→ JSON installation plan
→ dry run
→ backend
→ boot ShapeBit OS to a TTY
```

## Default installation

- UEFI;
- the entire selected disk;
- mandatory LUKS2;
- Btrfs;
- subvolumes for `/var`, `/home`, snapshots, and recovery data;
- systemd-boot;
- BLS entries;
- bootc image;
- initial user;
- console-only final system.

## MVP criteria

1. Detect a disk in QEMU.
2. Create and validate a plan.
3. Perform a dry run.
4. Create GPT, LUKS2, and Btrfs.
5. Install the bootc image.
6. Install systemd-boot and BLS.
7. Create a user.
8. Boot to a TTY.
9. Produce a correct error report after interruption.
10. Never report false success.
