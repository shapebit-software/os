# ADR-0001: Fedora + bootc as the System Base

**Status:** Accepted  
**Date:** 2026-08-04

## Context

ShapeBit OS requires a modern desktop stack, atomic updates, rollback, systemd, good Wayland support, and the ability to build custom images.

Options considered:

- Fedora + bootc;
- Arch + custom A/B;
- Debian + A/B/dm-verity;
- openSUSE MicroOS.

## Decision

ShapeBit OS will initially be built as a derivative Fedora bootc image.

## Rationale

- ready-made image-based model;
- OCI images;
- close alignment with systemd, PipeWire, NetworkManager, Flatpak, and SELinux;
- modern kernel and Mesa;
- straightforward CI/CD;
- lower cost of creating a secure updater than with Arch;
- ability to focus on the desktop and UX.

## Positive consequences

- rapid prototype development;
- transactional deployments;
- simpler release channels;
- rollback;
- straightforward image versioning and signing.

## Negative consequences

- no native Fedora rolling release;
- periodic migrations between Fedora base versions;
- dependency on RPM/DNF, SELinux, and the bootc ecosystem;
- need to track Fedora Image Mode maturity.

## Decision review

Re-evaluate the decision after reaching M3 or if bootc presents major limitations.
