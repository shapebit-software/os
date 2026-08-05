# 05. Updates, Deployments, and Recovery

**Status:** Proposed  
**Owner:** Core Platform / Release Engineering  
**Last updated:** 2026-08-04  
**Related ADRs:** ADR-0004, ADR-0006, ADR-0007, ADR-0008, ADR-0009

## 1. Purpose

This document describes the complete ShapeBit OS release lifecycle:

- discovering an available release;
- downloading and verifying the image;
- preparing a deployment;
- reboot and first boot;
- health checks and release acceptance;
- manual and automatic rollback;
- data migrations;
- recovery without a working main session;
- suspension of defective updates.

## 2. Update unit

The update unit is a specific, signed OCI image digest:

```text
registry.shapebit.software/os/x86_64@sha256:<digest>
```

A channel tag such as `stable` is only a mutable pointer:

```text
stable → sha256:AAA
testing → sha256:BBB
```

The device records the digest, not just the tag name.

## 3. Deployment states

ShapeBit OS distinguishes:

```text
booted     – currently running
pending    – prepared for the next boot
rollback   – previous known deployment
pinned     – administratively retained deployment
recovery   – independent rescue environment
```

At minimum, a device retains:

1. the currently booted deployment;
2. the previous accepted deployment;
3. a pending deployment when an update is prepared;
4. recovery outside normal deployment rotation.

## 4. Update state machine

```text
IDLE
  ↓ check
AVAILABLE
  ↓ approve/policy
DOWNLOADING
  ↓ verify
STAGED
  ↓ reboot
FIRST_BOOT
  ↓ health checks
ACCEPTED
```

Failure paths:

```text
DOWNLOADING → FAILED_DOWNLOAD → IDLE
VERIFYING   → FAILED_VERIFY   → QUARANTINED
FIRST_BOOT  → FAILED_HEALTH   → ROLLBACK_PENDING
ROLLBACK_PENDING → reboot → ROLLED_BACK
```

Every state and error must be persistent and visible in the diagnostic report.

## 5. Update checks

The updater downloads a signed channel manifest containing at least:

- image digest;
- ShapeBit OS release number;
- minimum supported source version;
- required bootloader/updater level;
- required space;
- update category;
- security deadline, when applicable;
- known hardware blocks;
- critical data-schema versions;
- release-notes address;
- manifest signature.

The updater does not trust only a registry response or OCI tag.

## 6. Update categories

### Standard

An ordinary feature and bug-fix release.

### Security

A vulnerability-fix release. It may use an accelerated rollout.

### Critical

A fix for a problem that prevents safe operation or updating.

### Base transition

A change of the base Fedora release or a significant ABI.

### Recovery update

An independent, less frequent recovery-environment update.

## 7. Pre-download checks

The updater checks:

- power source and battery level;
- network availability according to user policy;
- free space;
- filesystem state;
- absence of an active migration;
- absence of a pending deployment requiring a decision;
- hardware compatibility;
- minimum updater version;
- ability to retain rollback;
- absence of an active release block.

Insufficient space must not cause deletion of the last accepted rollback.

## 8. Download

Requirements:

- resumable downloads;
- bandwidth limits;
- metered-network policy;
- no blocking of normal work;
- atomic transition from `download` to `verified`;
- removal of unused parts after failure;
- progress metrics without false precision.

Power loss during download must not change the device's bootable state.

## 9. Verification

Before staging, verify:

1. registry identity;
2. release-manifest signature;
3. image signature or attestation;
4. digest match;
5. permitted base source;
6. architecture;
7. Secure Boot policy;
8. SBOM and required policy gates;
9. blocks against the specific build.

Failed verification quarantines the artifact and stops rollout.

## 10. Deployment staging

After verification, bootc prepares a new deployment without modifying the running `/usr`.

Staging must:

- retain the booted deployment;
- retain the last accepted deployment;
- create a pending deployment;
- prepare a bootloader entry;
- record a transaction ID;
- perform no destructive data migration;
- pass static deployment validation.

## 11. Pre-reboot validation

Before displaying "ready to restart," check:

- presence of the kernel and initramfs;
- correct bootloader entry;
- deployment metadata consistency;
- presence of critical systemd units;
- valid SELinux policies;
- availability of an unlock/recovery key;
- image completeness;
- ability to select the previous deployment.

## 12. Reboot

The user may:

- reboot immediately;
- choose a later time;
- allow reboot within a defined window;
- cancel a pending update before first boot when policy permits.

The system does not reboot automatically during active work without clear advance notice.

## 13. First boot

The new deployment starts in trial state:

```text
pending → trial boot
```

It is not yet considered known-good.

In the initramfs or very early userspace, record:

- boot-attempt number;
- transaction ID;
- selected deployment;
- start time;
- previous restart reason, when available.

## 14. Health-check levels

### L0 — Boot chain

- the bootloader loaded the correct entry;
- the kernel started;
- encrypted storage was unlocked;
- root/deployment was mounted.

### L1 — Base system

- the required systemd target was reached;
- all critical mounts are available;
- journald works;
- D-Bus works;
- the updater/recovery agent works;
- no critical SELinux policy-load failure occurred.

### L2 — Desktop platform

- logind works;
- the compositor can start;
- the shell starts basic components;
- the desktop portal responds;
- a login screen or session can be displayed.

### L3 — Device functions

- basic networking is available or correctly reports no connection;
- the basic graphics stack has not failed;
- storage is not read-only because of an error;
- no critical service is crash-looping.

### L4 — Observation period

After login or a defined time:

- no repeated compositor crashes;
- no critical mount/storage errors;
- no failed migration;
- no watchdog reset;
- basic settings and the Flatpak portal work.

## 15. Deployment acceptance

A deployment becomes `accepted` when:

1. it passes L0–L3;
2. critical migrations succeed;
3. the system runs for the minimum observation period or the user logs in successfully;
4. no critical crash loop occurs;
5. the health agent writes a persistent success marker.

Only then may older, unpinned deployments be removed according to retention policy.

## 16. Attempt counting and automatic rollback

A new deployment has a limited number of attempts; proposed default:

```text
3 failed boot attempts
```

A failed attempt includes:

- watchdog reset before reaching L1;
- no success marker before restart;
- kernel panic;
- unlocking failure caused by the system;
- critical root-mount error;
- an explicit failed health check.

After the limit, the bootloader should select the last accepted deployment.

### Important

Automatic rollback must not activate after:

- normal user shutdown;
- power loss after successful acceptance;
- an incorrect LUKS passphrase;
- hardware failure shared by both deployments;
- deliberate entry into recovery.

## 17. Manual rollback

Available from:

- the settings GUI while the system works;
- the bootloader menu;
- recovery;
- an administrator CLI.

The UI displays:

- current version;
- previous version;
- installation date;
- rollback reason;
- data-compatibility warning;
- impact on applications and settings.

Rollback does not revert `/home` or all of `/var`.

## 18. Data migrations

### Before reboot

Only migrations safe for the active system are permitted, such as preparing a backup or downloading resources.

### During first boot

Critical migrations:

```text
detect schema
→ validate
→ backup component state
→ migrate
→ verify
→ record result
```

### Rules

- migrations must not be hidden in arbitrary `%post` scripts;
- every migration has an owner and timeout;
- a critical migration blocks acceptance;
- a non-critical migration must not prevent login;
- rollback after migration must respect the N-1 contract;
- irreversible migrations require an explicit "rollback no longer safe" point.

## 19. Rollback barrier

Some changes may make an older deployment unsafe.

Such a release declares:

```text
rollback_barrier = true
```

Before updating, the system:

- performs the required backup;
- clearly informs the user;
- may require a recovery update;
- does not promise automatic rollback beyond the defined point;
- prefers a compatible two-stage migration over a barrier.

A rollback barrier is an exception requiring separate release-engineering approval.

## 20. Deployment retention

Default policy:

- booted accepted;
- one previous accepted;
- one pending;
- optionally one user/developer-pinned deployment;
- recovery outside normal retention.

Cleanup retains every object required by these deployments.

## 21. Staged updates

Stable rolls out in waves:

```text
internal → 1% → 5% → 20% → 50% → 100%
```

Progress between waves depends on:

- boot success rate;
- rollback rate;
- crash rate of critical components;
- hardware-specific problems;
- security reports;
- manual approval for larger releases.

Devices are assigned deterministically to cohorts so they do not change groups on each check.

## 22. Suspending and withdrawing a release

The release service must support:

- immediate suspension of new installations;
- blocking a specific digest;
- reverting a channel tag;
- publishing a superseding build;
- forced rollback only in extreme security cases;
- a message visible in the updater.

Reverting a tag does not change devices already running that digest. An explicit remediation mechanism is required.

## 23. Offline updates and constrained networks

Later plan:

- export a signed update bundle;
- import through USB;
- complete offline verification;
- no trust in the medium;
- ability to update recovery;
- exportable result report.

The MVP may require a network, but the manifest format must not prevent a later offline mode.

## 24. Recovery environment

Recovery must work independently of the main compositor and most system services.

Minimum functions:

- choose the booted/previous deployment;
- unlock LUKS;
- check storage;
- repair bootloader entries;
- download a known stable image;
- switch the channel to stable;
- export user data;
- generate a diagnostic report;
- reset the system;
- perform a full factory reset.

## 25. Recovery form

Recommendation:

```text
separate, minimal recovery image
```

It should not be merely another main-system deployment, because a shared compositor, library, or configuration defect could break both environments.

Recovery should:

- use a minimal graphical stack or TUI;
- have its own toolset;
- update less frequently;
- be signed with a separate profile;
- avoid mounting `/home` unnecessarily;
- mount data read-only by default during diagnostics.

## 26. Recovery updates

Recovery has its own version number and channel.

A recovery update:

1. is staged separately;
2. verifies the new image;
3. retains the previous variant or an emergency boot method;
4. does not coincide with a risky bootloader change without additional tests.

## 27. Update UX

The user sees:

- what will be updated;
- download size;
- whether a reboot is required;
- security category;
- known limitations;
- preparation status;
- ability to reboot later;
- whether the previous version is available.

By default, do not display:

- OCI layers;
- thousands of RPMs;
- OSTree operations;
- technical deployment names.

Details remain available in an advanced view.

## 28. Update-quality telemetry

Only according to the privacy policy and with user consent.

Minimum technical events:

- anonymous build ID;
- hardware class;
- boot result;
- highest health-check level reached;
- rollback yes/no;
- migration error code;
- time to acceptance.

Do not send:

- usernames;
- log contents;
- filenames;
- network addresses;
- document lists;
- secrets.

## 29. Mandatory tests

Every stable candidate must pass:

1. clean installation;
2. update from the previous stable;
3. update from the oldest supported stable;
4. interrupted download;
5. power loss during staging;
6. power loss during first boot;
7. manual rollback;
8. automatic rollback after failed boot;
9. `/etc` conflict;
10. `/var` migration;
11. insufficient space;
12. invalid signature;
13. unavailable registry;
14. update on battery power;
15. boot and rollback on reference hardware.

## 30. MVP criteria

M2 is complete when:

- two images can be promoted between channels;
- the device downloads a specific digest;
- staging does not change the running system;
- the new deployment works after reboot;
- manual rollback works;
- a simulated failure returns to the accepted deployment;
- status is visible in the CLI and a simple UI;
- recovery can select the previous deployment;
- every operation has a transaction ID and diagnostic log.

## 31. Open decisions

- systemd-boot or GRUB for the first prototype;
- exact boot-counting mechanism;
- minimum observation period before acceptance;
- number of boot attempts;
- how to recognize an intentional shutdown;
- recovery form: TUI or minimal GUI;
- maximum security-update deferral period;
- whether users may pin a deployment;
- how long updates from very old stable releases remain supported;
- OCI signing and attestation infrastructure.
