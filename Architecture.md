# Architecture

ShapeBit OS is an image-based Linux desktop operating system built on Fedora
bootc. Its architecture is organized by system area so each rule has one
canonical home and related details stay together.

These pages describe intended architecture, not implementation evidence.
Unlabeled sections are the current design. A **Proposed** label marks a section
that still requires explicit review and validation; it will be removed after
that review.

## System areas

- [Base System](base-system.md) — system foundation, storage, hardware scope,
  platform services, validation, and the delivery tracker.
- [Boot and System Lifecycle](boot-system-lifecycle.md) — installation, boot,
  releases, updates, migrations, and signing operations.
- [Security and Identity](security-identity.md) — encryption, authentication,
  authorization, networking, remote access, and credentials.
- [Application Platform](application-platform.md) — system applications,
  Flatpak, AppImage, Distrobox, and recommendations.
- [Desktop Environment](desktop.md) — desktop product design, session
  boundaries, displays, power, media, and notifications.
- [Diagnostics and Recovery](diagnostics-recovery.md) — reports, rollback,
  repair, reset, independent recovery, and Recovery Kit handling.
