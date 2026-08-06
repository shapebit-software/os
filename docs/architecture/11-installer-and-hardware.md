# 11. Installer and Hardware

**Status:** Proposed

**Owner:** Installer / Core Platform

**Last updated:** 2026-08-05

**Related ADRs:** ADR-0010, ADR-0011, ADR-0012

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
create_system_luks
enroll_system_tpm2
enroll_device_recovery_key
create_btrfs
create_subvolumes
install_bootc_image
install_systemd_boot
configure_recovery
create_homed_user
enroll_home_recovery_key
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
- one encrypted physical root covering `/usr`, `/etc`, `/var`, and `/root`;
- TPM2 automatic unlock for the system volume;
- a separate device recovery key;
- Btrfs;
- subvolumes for persistent system state, snapshots, and recovery data;
- one `systemd-homed` LUKS2 container per human user;
- systemd-boot;
- signed UKI boot entries;
- provisioned Secure Boot public certificates;
- bootc image;
- initial user;
- zram swap with no disk-backed swap;
- console-only final system.

## MVP criteria

1. Detect a disk in QEMU.
2. Create and validate a plan.
3. Perform a dry run.
4. Create GPT, the system LUKS2 volume, and Btrfs.
5. Enroll TPM2 automatic unlock using the approved PCR policy and enroll a
   device recovery key.
6. Install the bootc image.
7. Install systemd-boot and signed UKIs, then verify Secure Boot trust.
8. Create a `systemd-homed` user and separate recovery key.
9. Boot to a TTY without a system-volume password prompt.
10. Authenticate once, unlock the user's home, and start the session.
11. Deactivate the home after the user's final logout.
12. Boot with the device recovery key after simulated TPM loss.
13. Confirm that no plaintext disk-backed swap exists.
14. Produce a correct error report after interruption.
15. Never report false success.

The installation plan contains user and home-storage policy but no passwords or
recovery keys. Enrollment secrets travel through a separate short-lived channel
and never enter the transaction log.
