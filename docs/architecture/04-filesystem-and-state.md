# 04. Filesystem and Persistent State

**Status:** Proposed  
**Owner:** Core Platform  
**Last updated:** 2026-08-04  
**Related ADRs:** ADR-0002, ADR-0003, ADR-0004, ADR-0005

## 1. Purpose

This document defines:

- which parts of the system belong to the ShapeBit OS image;
- which data survives updates and rollbacks;
- where components may write configuration and state;
- how persistent-data migrations work;
- how encryption, backup, and factory reset work;
- what guarantees applications, services, and users receive.

This is one of the project's most important specifications. Incorrect data boundaries produce a system that cannot be safely updated or rolled back.

---

## 2. Governing principle

ShapeBit OS separates three classes of data:

```text
A. System image
   Code, libraries, systemd units, default configuration

B. Device state
   Configuration of a specific machine and system-service data

C. User data
   Documents, settings, keys, and application data
```

They primarily map to:

```text
A → /usr
B → /etc and /var
C → /home
```

Rolling back the system image does not automatically roll back device state or user data.

---

## 3. Target layout

| Path | Owner | Persistence | Mutability | Notes |
|---|---|---:|---:|---|
| `/usr` | ShapeBit OS image | per deployment | read-only at runtime | vendor code and resources |
| `/opt` | image/extensions | per deployment | read-only at runtime | approved components only |
| `/etc` | administrator/system | persistent | writable | machine configuration only |
| `/var` | system services | persistent | writable | dynamic host state |
| `/home` | user | persistent | writable | user data and preferences |
| `/boot` | update system | controlled | restricted | no manual administration |
| `/efi` | boot chain | controlled | restricted | ESP partition |
| `/run` | runtime | ephemeral | writable | tmpfs, cleared after reboot |
| `/tmp` | runtime | ephemeral | writable | automatic cleanup policy |
| `/srv` | optional services | persistent | writable | intentional uses only |

Compatibility links:

```text
/bin   → /usr/bin
/sbin  → /usr/sbin
/lib   → /usr/lib
/lib64 → /usr/lib64
```

---

## 4. `/usr`: image contents

### 4.1 What belongs in `/usr`

- system binaries;
- libraries;
- kernel modules;
- firmware supplied by the image;
- vendor systemd units;
- udev rules;
- SELinux policies and modules;
- default configuration;
- compositor and shell resources;
- session metadata;
- portals;
- locale files and system documentation.

### 4.2 Rules

1. `/usr` is read-only during normal operation.
2. `/usr` changes only through a new image/deployment.
3. Official services must not generate persistent files in `/usr`.
4. The build system may write to `/usr` while creating the image.
5. Every file in `/usr` must have an owner: an RPM package or an explicit image-composition step.
6. Files copied directly with `COPY` are allowed in prototypes, but production use should be limited to image configuration and metadata.

### 4.3 Default configuration

Preferred hierarchy:

```text
/usr/lib/<component>/
/usr/share/<component>/
/usr/lib/systemd/system/
/usr/lib/sysusers.d/
/usr/lib/tmpfiles.d/
/usr/lib/environment.d/
```

A component should load vendor settings from `/usr` first, then administrator overrides from `/etc`.

---

## 5. `/etc`: device configuration

### 5.1 Role

`/etc` contains persistent configuration for a specific device. It is not part of the current deployment in the same way as `/usr`.

Permitted examples:

- hostname;
- system locale and keyboard settings;
- login configuration;
- networking configuration that requires host scope;
- administrator policies;
- systemd unit overrides;
- bootc and update-channel configuration;
- administrator-trusted certificates;
- enterprise configuration.

### 5.2 Prohibited data

The following do not belong in `/etc`:

- caches;
- queues;
- databases;
- operation history;
- logs;
- user session tokens;
- unbounded growing data;
- compiled artifacts;
- dynamic device state;
- ordinary user-application configuration.

### 5.3 Defaults

Vendor defaults should be stored in `/usr` whenever possible.

```text
/usr/lib/shapebit-os/defaults/       – vendor settings
/etc/shapebit-os/                    – device overrides
~/.config/                         – user preferences
```

### 5.4 systemd overrides

Package unit:

```text
/usr/lib/systemd/system/shapebit-updater.service
```

Local override:

```text
/etc/systemd/system/shapebit-updater.service.d/override.conf
```

Do not copy an entire unit into `/etc` when a drop-in is sufficient.

### 5.5 File ownership

Every file in `/etc` should belong to one of these classes:

| Class | Example | Management |
|---|---|---|
| generated during installation | `machine-id`, locale | installer/first boot |
| service-managed | channel configuration | specific service |
| administrator override | systemd drop-in | administrator |
| host secret | device keys | dedicated store, restrictive ACLs |
| historical residue | unused configuration | detected and reported |

### 5.6 Update policy

An image update may change the default configuration. The system must:

1. preserve local modifications;
2. apply new values to files not locally modified;
3. detect conflicts;
4. never silently overwrite a conflict;
5. record diagnostics;
6. on conflict, use a safe default or preserve the previous value according to component policy.

### 5.7 Configuration registry

ShapeBit OS should maintain a local index at:

```text
/var/lib/shapebit-config-state/
```

For managed files, record:

- path;
- factory-value hash;
- local-value hash;
- schema version;
- owning component;
- result of the last migration;
- conflict status.

The index does not replace bootc; it supports diagnostics, the settings UI, and migrations of custom components.

---

## 6. `/var`: persistent system state

### 6.1 Layout

| Path | Purpose |
|---|---|
| `/var/lib` | persistent service state |
| `/var/cache` | reproducible data |
| `/var/log` | logs |
| `/var/spool` | queues |
| `/var/tmp` | temporary files that survive reboot |
| `/var/lib/flatpak` | system-wide Flatpak installations |
| `/var/home` | possible physical home location under OSTree/bootc |
| `/var/mnt` | persistent system-managed mount points |
| `/var/lib/containers` | system-container data, if supported |

### 6.2 Service rules

Each service owns its own directory:

```text
/var/lib/shapebit-updater/
/var/lib/shapebit-accounts/
/var/lib/shapebit-store/
```

Services do not share writable directories without an explicit contract.

systemd units should use the following where possible:

```ini
StateDirectory=shapebit-updater
CacheDirectory=shapebit-updater
LogsDirectory=shapebit-updater
RuntimeDirectory=shapebit-updater
```

### 6.3 Caches

A cache must be:

- safe to delete;
- automatically reproducible;
- size-limited;
- never the only copy of important data.

### 6.4 Logs

Default policy:

- journald is persistent;
- its size is limited;
- older logs are rotated;
- diagnostic reports can export a selected range;
- sensitive data should be redacted by the source component;
- debug logging is disabled in stable.

### 6.5 Containers

Toolbox/Podman data belongs to the user and should be stored in the user's data space. System containers are a separate feature and should not automatically share storage with user containers.

---

## 7. `/home`: user data

### 7.1 Scope

- documents;
- downloads;
- application configuration;
- per-user Flatpak data;
- user keys;
- code repositories;
- rootless containers;
- local SDKs and development caches.

### 7.2 XDG Base Directory

Custom applications must respect:

```text
~/.config      – configuration
~/.local/share – persistent data
~/.cache       – cache
~/.local/state – user state
```

Do not create new hidden directories without justification.

### 7.3 Rollback

A system rollback:

- does not roll back `/home`;
- does not remove new user files;
- may run an older application/system version against newer data.

User-data formats must therefore remain backward-compatible where possible, or migrations must support the rollback window.

---

## 8. Partition and volume model

### 8.1 First-prototype proposal

```text
GPT
├── EFI System Partition
├── /boot
└── LUKS2
    └── Btrfs
        ├── @var
        ├── @home
        ├── @snapshots
        └── @recovery-data
```

The actual `/usr` and root deployment is managed by bootc/OSTree. Persistent data resides under `/var`, while home may be exposed logically as `/home`.

### 8.2 Why Btrfs for data

Planned benefits:

- subvolumes;
- snapshots;
- data and metadata checksums;
- compression;
- easier quotas;
- send/receive for future backups.

Btrfs is not a bootc requirement. It is a separate ShapeBit OS decision about persistent data.

### 8.3 Conservative alternative

```text
LUKS2
├── XFS or ext4 for /var
└── ext4 for /home
```

This reduces snapshot complexity but limits backup and state-management features.

### 8.4 Preliminary decision

Use Btrfs inside LUKS2 for the prototype and reference desktop. Before M7, validate the decision with power-failure, low-space, snapshot, and recovery tests.

---

## 9. Encryption

### 9.1 Scope

Encrypt persistent device data by default:

- `/var`;
- `/home`;
- swap;
- recovery data containing user data.

The ESP and required boot-chain elements are not encrypted, but must be protected by Secure Boot and integrity measurements.

### 9.2 MVP model

- LUKS2;
- user recovery passphrase;
- optional automatic TPM2 unlocking;
- key rotation;
- separate recovery key;
- no keys sent to the system vendor.

### 9.3 TPM

The TPM provides convenience and additional key protection; it is not the only recovery mechanism.

The system must define procedures for:

- firmware changes;
- TPM reset;
- motherboard replacement;
- Secure Boot failure;
- loss of automatic unlocking.

---

## 10. Swap and hibernation

### 10.1 Default policy

MVP:

- zram as the primary swap;
- no hibernation in the first public release;
- no unprotected swap partition.

### 10.2 Future hibernation

Hibernation requires:

- encrypted swap;
- binding the resume image to the current deployment;
- testing after kernel updates;
- invalidating hibernation when the deployment changes.

Hibernation must not prevent safe rollback.

---

## 11. Data migrations

### 11.1 Problem

An image can be rolled back quickly; persistent data cannot be safely rolled back without a plan. A new service may change a database schema in `/var`, leaving the previous deployment unable to read it.

### 11.2 Rules

1. Every component with persistent state has a schema number.
2. Migrations are idempotent.
3. Every migration records a log.
4. A component backup is created before a destructive migration.
5. Forward- and backward-compatible migrations are preferred during the rollback window.
6. A service must not start with an unsupported schema.
7. Migrations run before the dependent component fully starts.
8. `/var` is not rolled back globally.

### 11.3 Migration phases

```text
prepare → validate → backup → migrate → verify → commit
```

On failure:

```text
fail → restore component backup → mark deployment unhealthy
```

### 11.4 Component contract

Every stateful service must document:

- data paths;
- current schema version;
- compatibility range;
- backup procedure;
- restore procedure;
- maximum supported downgrade;
- migration space cost.

---

## 12. Snapshots

### 12.1 What we do not do

Do not tie each image rollback to an automatic snapshot of all of `/home`; that could revert documents and create unclear behavior.

### 12.2 System-state snapshots

Selective snapshots are allowed:

- before migrating an important `/var` database;
- before factory reset;
- before a repair operation;
- for user backups.

### 12.3 Retention

Snapshots must have:

- an owner;
- a creation reason;
- an expiration date;
- a space limit;
- automatic cleanup.

---

## 13. Backup

### 13.1 First-release scope

The MVP provides user-data export, not a complete cloud service.

Backups should include:

- selected user directories;
- application configuration;
- the installed-Flatpak list;
- basic ShapeBit OS settings;
- optionally, secrets with separate consent.

### 13.2 Excluded by default

- caches;
- container images;
- entire SDKs;
- logs;
- system `/usr`;
- downloadable Flatpak runtimes;
- temporary snapshots.

### 13.3 Format

A backup must be:

- versioned;
- verifiable;
- optionally encrypted;
- independent of a specific deployment;
- tested through automated restoration.

---

## 14. Factory reset

### 14.1 Modes

#### System reset

- restores the stable image;
- clears host configuration;
- preserves `/home`;
- repeats system onboarding.

#### Full reset

- removes all accounts and data;
- restores the default partition/logical layout;
- generates new device keys;
- restores the factory/stable image.

#### Single-user reset

- removes the account and its data;
- does not change the base system.

### 14.2 Security

A full reset must require:

- authentication;
- unambiguous confirmation;
- a summary of data to be removed;
- protection against accidental invocation by an application.

---

## 15. Developer mode

### 15.1 Rule

Developer mode does not change the persistent system contract.

Preferred mechanisms:

- Toolbox/Podman;
- nested compositor;
- VM;
- developer-channel image;
- temporary writable overlay removed after reboot.

### 15.2 Unsupported model

Persistent manual copying of files into `/usr` on stable is not an officially supported workflow.

### 15.3 Testing `/etc` changes

Developers may use:

- a dedicated drop-in;
- an experimental directory;
- a VM profile;
- a temporary overlay;
- component configuration reset.

Every local change should appear in the diagnostic report as "device divergence."

---

## 16. Space limits and failures

### 16.1 Reserve

The system must retain enough reserve to:

- download an update;
- create a deployment;
- write critical logs;
- make a small migration backup.

### 16.2 Low-space behavior

Space-recovery order:

1. update cache;
2. old images that are neither current nor rollback;
3. system caches;
4. old logs;
5. expired snapshots;
6. propose removal of large user data—only with consent.

### 16.3 Data protection

The updater does not start unless enough space exists for:

- the new deployment;
- rollback;
- required migrations;
- a safety margin.

---

## 17. Diagnostic report

The report should contain:

- active and previous deployments;
- filesystem usage;
- subvolume list;
- encryption state;
- results of recent migrations;
- `/etc` conflicts;
- local systemd overrides;
- unmanaged files in protected locations;
- snapshot state;
- mount errors;
- read-only `/usr` state.

The report does not contain document contents or secrets.

---

## 18. Acceptance criteria

The filesystem/state architecture is ready for implementation when tests confirm that:

1. updates do not change user data;
2. rollback boots the previous deployment;
3. local `/etc` configuration is preserved;
4. configuration conflicts are detected;
5. a service with a newer schema does not damage downgrade;
6. insufficient space blocks an update before system changes;
7. power loss does not leave a partial deployment;
8. factory reset works in both modes;
9. the recovery key decrypts data without the TPM;
10. a backup can be restored on a fresh installation.

---

## 19. Open questions

- Will the physical home be `/var/home` or a separate `/home` mount?
- Will `/var` and `/home` share one LUKS/Btrfs volume?
- How long is the previous deployment retained?
- Does stable permit local administrator drop-ins?
- How are `/etc` conflicts presented in the GUI?
- Are system Flatpaks part of the installer image or first boot?
- How does recovery work after Btrfs corruption?
- Does backup cover GNOME Keyring/Secret Service secrets?
- When will hibernation be introduced?
- What is the minimum free space required for an update?
