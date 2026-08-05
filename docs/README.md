# ShapeBit OS — Architecture Documentation

**Status:** conceptual design  
**Base:** Fedora + bootc  
**System model:** image-based, atomic, transactional  
**Application layer:** Flatpak  
**Development layer:** Toolbox/Podman + developer images  
**Desktop:** custom Wayland compositor and desktop environment

## Project goal

ShapeBit OS is intended to be a consumer Linux desktop system that:

- is simple and predictable for ordinary users;
- updates as a coherent image;
- supports safe rollback;
- limits accidental modification of the base system;
- remains open and convenient for developers;
- develops a custom, coherent desktop and platform API.

## Governing principles

1. The base system is built as a versioned OCI image.
2. Official devices do not update through direct `dnf upgrade` operations.
3. An update creates a new deployment activated after reboot.
4. The previous working deployment remains available.
5. User applications are installed primarily as Flatpaks.
6. Development toolchains run in containers.
7. Host components enter the image during its build.
8. Every stable release must pass boot, update, and rollback tests.
9. `/usr` belongs to the image; persistent state belongs in `/var` and `/home`.
10. The user interface should not expose base-distribution details.

## Documents

| Document | Scope |
|---|---|
| `01-product-vision.md` | product vision, audience, and principles |
| `02-system-architecture.md` | system layers and responsibility boundaries |
| `03-image-and-build-model.md` | bootc image, RPMs, and composition process |
| `04-filesystem-and-state.md` | `/usr`, `/etc`, `/var`, `/home`, and persistent state |
| `05-updates-and-recovery.md` | updates, deployments, rollback, and recovery |
| `06-release-channels.md` | developer, nightly, testing, and stable |
| `07-application-model.md` | Flatpak, containers, and host extensions |
| `08-development-workflow.md` | daily development, SDKs, VMs, and integration |
| `09-security-model.md` | Secure Boot, SELinux, encryption, and signatures |
| `10-desktop-platform.md` | compositor, shell, portals, and platform API |
| `11-installer-and-hardware.md` | installation and supported-hardware policy |
| `12-ci-cd-and-testing.md` | pipeline, tests, publishing, and image promotion |
| `13-roadmap.md` | milestones and implementation sequence |
| `decisions/ADR-0001-fedora-bootc.md` | first architecture decision |
| `decisions/ADR-TEMPLATE.md` | template for subsequent decisions |

## Document statuses

- **Draft** — working material.
- **Proposed** — ready for discussion.
- **Accepted** — binding decision.
- **Deprecated** — replaced by a new decision.
- **Superseded** — points to a successor document.

## Next step

The first document to develop further should be `04-filesystem-and-state.md`, because it affects updates, configuration, recovery, backup, and developer mode.

## Detailed persistent-state decisions

- `decisions/ADR-0002-filesystem-ownership.md`
- `decisions/ADR-0003-persistent-storage-btrfs-luks.md`
- `decisions/ADR-0004-data-migrations-and-rollback.md`
- `decisions/ADR-0005-reset-backup-and-home.md`
- `checklists/persistent-state-component.md`

## Detailed update and recovery decisions

- `decisions/ADR-0006-update-unit-oci-digest.md`
- `decisions/ADR-0007-trial-boot-and-acceptance.md`
- `decisions/ADR-0008-independent-recovery.md`
- `decisions/ADR-0009-staged-rollout.md`
- `checklists/update-release-candidate.md`

## Nearest implementation target

- `14-first-prototype.md` — first console-only image and installer integration.
- `decisions/ADR-0010-dioxus-installer.md` — Dioxus decision.
