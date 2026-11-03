# Base System

The hardware ShapeBit runs on, how its disk is laid out, and how homes share
its space.

## Hardware

- A 64-bit PC (x86-64) with UEFI, Secure Boot, and a TPM 2.0.
- Automated tests run on QEMU with UEFI firmware and a software TPM.

## Disk Layout

The disk has two partitions: an EFI System Partition, not encrypted, and a
LUKS2 volume that holds everything else.

```text
GPT
├── EFI System Partition    boot files, signed; no secrets
│   ├── Fedora's shim (signed by Microsoft)
│   ├── systemd-boot, signed by ShapeBit
│   └── the UKIs of the installed releases, signed by ShapeBit
└── LUKS2                   everything else, encrypted
    └── Btrfs
        ├── @base       the system, read-only, and each release's /etc
        ├── @machine    this computer's state (/var)
        ├── @people     the homes (/home)
        └── @recovery   reserved for recovery
```

> **Goal, not built:** ShapeBit's own shim in place of Fedora's
> ([Boot Trust](Architecture-Lifecycle.md#boot-trust)), and a minimal signed
> recovery UKI.

Machine configuration in `/etc` stays with the system: each release keeps its
own `/etc` and carries local changes forward on update.

Homes live in `@people` rather than `@machine` on purpose: a reset can wipe
the computer's state and still leave the homes untouched.

Each home is encrypted again, with its owner's password
([Security](Architecture-Security.md)).

## Home Storage

> **Planned.** Today each home takes the space systemd-homed gives it by
> default, which can leave too little room for updates.

Homes don't get fixed-size partitions. They share one pool:

- Each home is **guaranteed a minimum**.
- Beyond it, a home can **burst** into shared space, with no manual sizing.
- An owner can cap a home with a **hard limit**.
- A new home is created only if its minimum fits without taking space from
  another home or from the computer.

The computer keeps a **reserve** that homes can't burst into, so it never runs
out of room for logs, recovery, and staging an update:

```text
reserve = max(30 GiB, steady + surge)
```

- **steady**: what the computer always needs: 12 GiB, plus 2% of the disk
  (between 4 and 16 GiB) for filesystem metadata.
- **surge**: what an update needs while it's staged: the release's declared
  size (at least 12 GiB), plus any migration space it asks for.

When free space runs low, the computer warns at **low** (below 16 GiB or 10%
of the pool, whichever is larger) and **critical** (below 8 GiB), and reports
**exhausted** when no burst space is left.
