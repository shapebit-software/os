# 01. Product Vision

**Status:** Draft

## Problem

Traditional Linux distributions often require users to understand packages, repositories, dependencies, system configuration, and how to repair problems after updates. ShapeBit OS is intended to hide these mechanisms behind a coherent product model.

## Initial audience

The initial target audience consists of:

- technical users who want a stable desktop;
- developers;
- testers of the new graphical environment;
- users of Intel/AMD hardware with UEFI and TPM2.

The first release is not yet intended for completely non-technical users.

## Product promise

ShapeBit OS should:

- boot predictably;
- update without leaving the system partially changed;
- allow users to return to the previous version;
- protect each user's home while that user is logged out;
- use one password entry to authenticate and unlock the user's home;
- install applications without modifying the host;
- provide a consistent settings interface;
- provide a good development mode without compromising the production system.

## Out of scope for the first release

- full compatibility with arbitrary PC hardware;
- advanced user customization of the system;
- support for every GNOME/KDE extension;
- a custom application format;
- a custom kernel;
- a complete Windows- or macOS-compatible API;
- a polished application ecosystem from the first release.

## MVP success criteria

The MVP succeeds when the system:

1. installs and boots in QEMU;
2. starts a working Wayland session;
3. provides networking, audio, and Flatpak;
4. updates to a new image;
5. can perform a rollback;
6. generates a diagnostic report;
7. activates an independently encrypted home through the normal login flow;
8. can be reproduced from the source repository.
