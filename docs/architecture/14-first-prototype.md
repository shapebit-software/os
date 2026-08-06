# 14. First Working Prototype

**Status:** Proposed

## Goal

Boot ShapeBit OS in QEMU without a graphical environment, then install it using the backend of the future Dioxus installer.

This document is the canonical near-term implementation plan. The
[roadmap](13-roadmap.md) tracks later product milestones, while
[project status](../roadmap/PROJECT-STATUS.md) records completed and verified
work.

## Scope

- Fedora bootc;
- systemd-boot;
- signed UKI boot entries;
- bootc deployment backend;
- OVMF Secure Boot and swtpm;
- LUKS2;
- TPM2 automatic system-volume unlock;
- device recovery key;
- Btrfs;
- `systemd-homed`;
- PAM home activation;
- TTY;
- NetworkManager;
- administrative user;
- optional SSH.

## Sequence

### P0 — image repository

- `Containerfile`;
- package list;
- branding;
- build script;
- container execution test.

### P1 — bootable QEMU disk

- raw/QCOW2 image;
- UEFI;
- systemd-boot;
- signed UKI boot entries;
- provisioned development Secure Boot keys;
- LUKS2;
- TPM2 automatic unlock using PCR 7 and signed PCR 11 policy;
- device recovery-key boot;
- Btrfs;
- zram with no disk-backed swap;
- encrypted per-user home;
- one-password TTY login;
- home deactivation after final logout.

### P2 — update

- images A and B;
- `bootc update`;
- signed UKIs and sealed deployment verification;
- pre-reboot TPM2 authorization check for A and B;
- reboot;
- rollback.

### P3 — installer-backend contract

- `InstallationPlan` model;
- validation;
- dry run;
- transaction log;
- mock operations.

### P4 — real backend

- disk detection;
- partitioning;
- LUKS2;
- TPM2 enrollment;
- device recovery-key enrollment;
- Btrfs;
- bootc installation;
- systemd-boot;
- Secure Boot public-key enrollment;
- signed UKI installation;
- `systemd-homed` user creation;
- recovery-key enrollment;
- boot verification.

### P5 — Dioxus integration

- UI uses the mock;
- UI uses the real backend;
- installation to a virtual disk;
- system boots to a TTY.

## Repository organization

The `os` coordination repository uses implementation submodules:

```text
os/
├── docs/
├── image/                 # git submodule
└── installer/             # git submodule
    ├── ui/
    ├── backend/
    └── protocol/
```

`protocol` should be a separate Rust crate within the installer repository,
shared by the UI, backend, and tests.

## Initial contract

The installation plan is serializable and contains no secrets:

```json
{
  "target_disk": "/dev/vda",
  "system_encryption": {
    "type": "luks2",
    "unlock": "tpm2",
    "recovery_key": true
  },
  "system_filesystem": "btrfs",
  "swap": "zram",
  "bootloader": "systemd-boot",
  "image_reference": "registry.shapebit.software/os:developer",
  "user": {
    "username": "developer",
    "home_storage": "systemd-homed-luks2"
  }
}
```

The password and generated recovery key are intentionally absent. They use a
separate short-lived enrollment channel and must never be serialized into the
plan or transaction log.
