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
- BLS;
- OSTree backend;
- LUKS2;
- Btrfs;
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
- BLS;
- LUKS2;
- Btrfs;
- TTY login.

### P2 — update

- images A and B;
- `bootc update`;
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
- Btrfs;
- bootc installation;
- systemd-boot;
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
  "encryption": "luks2",
  "filesystem": "btrfs",
  "bootloader": "systemd-boot",
  "image_reference": "registry.shapebit.software/os:developer",
  "username": "developer"
}
```
