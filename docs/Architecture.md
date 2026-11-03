# Architecture

ShapeBit OS is an image-based Linux desktop operating system built on Fedora.

## System areas

Each page describes the design. Where something is not built yet, the page
says so.

- [Base System](Architecture-Base.md) — supported hardware, disk layout, and home
  storage.
- [Installation](Architecture-Installation.md) — the installer's parts, disk
  selection, secrets, and installation verification.
- [System Lifecycle](Architecture-Lifecycle.md) — signing, boot trust, release
  channels, distribution, updates, rollback, and release withdrawal.
- [Security](Architecture-Security.md) — disk encryption and the TPM unlock
  policy.
- [Recovery](Architecture-Recovery.md) — the recovery key and when it is needed.
- [Applications](Architecture-Applications.md) — built-in apps, third-party app
  installation, browsers, and AppImage.
- [Desktop Environment](Architecture-Desktop.md) — the session, bars,
  workspaces and windows, dictation, the assistant, Settings, and Welcome as
  built; the future design of menus, the Shelf, and voice and gaze input.
