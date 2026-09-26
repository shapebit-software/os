# Installation

This page describes how the installer prepares a device: capability
discovery, network setup, credential handling, disk selection, and the
installation itself.

## Capabilities

Before showing any choices, the frontend asks the backend what's possible — which disks are eligible, whether UEFI, Secure Boot, and TPM2 are available, connectivity, Wi-Fi, and the supported locales, time zones, and keyboard layouts.

## Wi-Fi

If there's no working internet connection, the frontend offers a Wi-Fi step. The user can connect or skip it — lack of internet never blocks installation.

## Sending Passwords and Keys Safely

Passwords, Wi-Fi credentials, recovery keys, and anything derived from them never travel over the ordinary control connection, and never end up in the plan, a capability snapshot, an event, an error, logs, or diagnostics.

Instead, each one crosses over a separate, one-shot channel dedicated to exactly that transfer, opened by the backend and torn down as soon as it's used or it expires.

## Choosing and Confirming the Disk

Installing erases one whole disk, and Linux device names like
`/dev/nvme0n1` aren't permanent — they can change as storage is attached, removed, or rediscovered.

So the plan, and the destructive confirmation that follows it, stay bound to the actual physical device the user reviewed — a stable identity built from things like its serial and WWN —
never to a device name. 

The backend re-resolves and re-checks that identity before accepting a plan, before confirming, and immediately before the destructive step; any relevant change clears the selection and
confirmation and requires a fresh one.

### Which disks are allowed

An eligible target is either an internal disk, or an external USB,
Thunderbolt, or eSATA disk that's clearly labelled as external and meets the same capacity and validation rules.

Never eligible: the disk the running installer itself booted from, read-only devices, ambiguous multipath devices.

### The final confirmation screen

Right before the destructive step begins, the frontend shows one screen with a short summary.

The user ticks **I understand that all data on this disk will be deleted** before **Erase disk and install ShapeBit** becomes available. 

## Installing

An installation moves through six phases, in order:

```text
validating → preparing → creating-storage → installing-system → configuring → verifying
```

- **validating** rechecks the plan, scan, disk, inputs, and policy — nothing changes yet.
- **preparing** gathers any remaining non-secret inputs — the target is still untouched.
- **creating-storage** erases the disk and lays down the GPT, the system LUKS2 volume, Btrfs, and encrypted-home storage
- **installing-system** writes the ShapeBit image and boot artifacts.
- **configuring** sets up the first owner, their home, an optional Wi-Fi profile, TPM2, trust, and recovery.
- **verifying** checks the whole installation and syncs it before declaring success.

### The destructive boundary

`validating` and `preparing` are non-destructive and offer an ordinary **Cancel**. The final disk confirmation above is what authorizes the one transition into `creating-storage` — entering that phase is the point of no easy return.

### Verifying and finishing

Before declaring success, `verifying` confirms at least:

- the GPT, LUKS2, and Btrfs identities and layout are correct;
- the installed image matches its exact digest;
- the required signed UKIs, systemd-boot entries, and recovery assets are present;
- the system and first-home keyslots work;
- TPM2 unlock and both enrolled recovery credentials work;
- the first owner exists and their encrypted home is active;
- their Wi-Fi profile was saved, if that was requested; and
- everything is synced and target filesystems are safely unmounted.

Internet access isn't required to finish, and testing the recovery
credentials must never reveal their values or invalidate the working keyslots.

Once every check passes, the user still has to see and acknowledge the Recovery Kit before the backend writes a durable installation-complete marker, reports the terminal `completed` result.