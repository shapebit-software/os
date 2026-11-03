# Installation

How the installer prepares a computer. To install ShapeBit, see
[Installing ShapeBit](Install.md).

## Two Parts

The installer is an unprivileged **frontend**, the pages a person sees, and a
privileged **backend** that does the work. The frontend only asks; the backend
checks every request, builds every command itself, and runs nothing the
frontend sends.

Before showing any choices, the frontend asks the backend what's possible:
which disks are eligible, whether UEFI, Secure Boot, and a TPM 2.0 are there,
whether there's a network, and which languages, time zones, and keyboard
layouts are supported.

## Steps

Language, keyboard layout, network, time zone, account, and disk, then the
installation and the recovery key. The network is optional: no internet
connection ever blocks installation.

## Secrets

Passwords, Wi-Fi credentials, and recovery keys never travel with the
ordinary requests, and never appear in the plan, events, errors, or logs.
Each crosses a separate one-time channel that the backend opens for exactly
that transfer and closes once it's used.

## Choosing and Confirming the Disk

Installing erases one whole disk. Device names such as `/dev/nvme0n1` can
change as storage comes and goes, so the choice and its confirmation are
bound to the disk's stable identity (its serial number or WWN), never to its
name. The backend checks that identity again before it accepts the plan,
when the person confirms, and right before it erases the disk; any change
clears the choice.

Eligible disks are internal disks, and external ones (USB, Thunderbolt,
eSATA) that are clearly labelled as external. Never eligible: the disk the
installer runs from, read-only devices, and ambiguous multipath devices.

The last screen before erasing shows the disk, and **Erase disk and install
ShapeBit** works only once the person ticks that all its data will be
deleted.

## Installing

An installation moves through six phases:

```text
validating → preparing → creating-storage → installing-system → configuring → verifying
```

- **validating** and **preparing** check the plan and gather inputs. Nothing
  changes yet, and **Cancel** works.
- **creating-storage** erases the disk and creates the
  [disk layout](Architecture-Base.md#disk-layout). The confirmation is what
  allows this step.
- **installing-system** writes the system and its signed boot files.
- **configuring** creates the first owner and their encrypted home, and
  enrolls the TPM and the recovery key.
- **verifying** checks the result before reporting success: the layout, the
  exact system image, the boot files, the owner and their home, and that each
  key unlocks the disk, without revealing or weakening any key.

The installer then shows the recovery key, which the person confirms they
saved.

## Not Built Yet

- Wi-Fi in the installer on a real computer.
- The hostname.
- The full Recovery Kit: a recovery key for the owner's home, a QR code,
  printing, and an encrypted export. Today only the disk's recovery key is
  shown, as text.
- Labelling external disks, and refusing ambiguous multipath devices.
- Resuming after the backend restarts, and a durable record that the
  installation completed.
