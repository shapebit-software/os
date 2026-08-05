# ShapeBit OS project status

**Last reviewed:** 2026-08-05

**Phase:** architecture and first-prototype scaffolding

This page records repository state, not target architecture. The ADRs are the
authority for accepted and proposed decisions.

## Current repository state

- The `os` repository contains product documentation and coordinates the
  implementation through Git submodules.
- The `image` submodule contains a Fedora bootc 44, console-only image scaffold,
  build and QEMU scripts, and container smoke tests.
- The `installer` submodule currently contains interface and safety guidance for
  the planned UI, protocol, and privileged backend. The Rust crates have not yet
  been implemented.
- The first active delivery target is a bootable QEMU disk that reaches a TTY.

## Verification state

The repository does not yet record a successful end-to-end image build, disk
creation, UEFI boot, or TTY login. Those capabilities remain implementation
targets until they have been exercised and their results recorded.

## Active plan

The canonical near-term sequence is the
[first working prototype](../architecture/14-first-prototype.md). The
[long-term roadmap](../architecture/13-roadmap.md) places that foundation in the
larger delivery sequence.

## Decision status

The accepted decisions currently recorded in ADRs are:

- [Fedora + bootc as the system base](../decisions/ADR-0001-fedora-bootc.md)
- [Dioxus as the installer frontend](../decisions/ADR-0010-dioxus-installer.md)

All other ADRs are currently marked **Proposed** and require review or
implementation validation before they become binding.

## Open decisions

Open design questions belong in the relevant architecture specification or ADR:

- persistent storage and encryption: [filesystem and persistent state](../architecture/04-filesystem-and-state.md)
- boot acceptance, updates, and recovery: [updates, deployments, and recovery](../architecture/05-updates-and-recovery.md)
- installer details: [installer and hardware](../architecture/11-installer-and-hardware.md)
