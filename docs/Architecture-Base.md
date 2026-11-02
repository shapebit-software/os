# Base System

This page describes the base system: the hardware OS targets, how disks
are laid out, and how home storage is managed.

## Hardware and Platform

- **Automated testing target:** x86-64 QEMU, with OVMF firmware and a software
  TPM.
- **Developer host:** Linux x86-64 with KVM. Fedora is the canonical host and
  the required CI environment.

## Disk Layout

Each OS disk has two parts: an EFI System Partition and an encrypted
LUKS2 volume.

```text
GPT
├── EFI                                   (boot files, not encrypted)
│   ├── Microsoft-signed OS shim
│   ├── normal signed boot artifacts
│   └── minimal signed recovery UKI
└── LUKS2                                 (everything else, encrypted)
```

Inside the LUKS2 volume, a single Btrfs filesystem is split into four
subvolumes:

```text
LUKS2
└── Btrfs
    ├── @base       system code, read-only     (/usr, /boot, ...)
    ├── @machine    this device's own state    (/var)
    ├── @people     user home data             (/home)
    └── @recovery   minimal recovery data
```

Machine configuration in `/etc` stays in `@base`: each system version keeps its
own `/etc` and carries local changes forward on update, so a reset restores it
through the update system rather than by wiping `@machine`.

Homes live in `@people` rather than `@machine` on purpose: resetting a device
wipes `@machine`, but a reset can still leave home data untouched.

## Home Storage

Homes don't get fixed-size partitions. Instead, every home draws from one
shared pool of space:

- Each home is **guaranteed a minimum** amount of space.
- Beyond that minimum, homes can **burst** into shared space as needed — no
  manual sizing required.
- An owner can cap a home with a **hard limit**; without one, a home can grow
  to use whatever the pool has free.
- A new home can only be created if its guaranteed minimum can be met without
  taking space away from an existing home or from the machine itself.

### Protecting space for the machine

The system always keeps a **reserve** of space that homes cannot burst into,
so the machine itself never runs out of room. That reserve is recalculated on
the fly from two parts:

```text
reserve = max(30 GiB, steady + surge)
```

- **steady** — space the machine always needs: 12 GiB fixed, for emergency
  recovery and logs, plus 2% of the disk's total capacity for filesystem
  metadata (kept between 4 and 16 GiB).
- **surge** — extra space needed only while an update is being staged: the
  release's declared staging size (at least 12 GiB), plus any migration space
  the release asks for (none, by default).

### Running low on space

| State       | Meaning                                                              |
| ----------- | --------------------------------------------------------------------- |
| `low`       | Free space has dropped below 16 GiB or 10% of the pool, whichever is larger. |
| `critical`  | Free space has dropped below 8 GiB.                                   |
| `exhausted` | No more burst space is available at all.                              |
