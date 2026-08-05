# 09. Security Model

**Status:** Draft

## Goals

- ensure image authenticity;
- protect data after device theft;
- limit the impact of a malicious application;
- restrict system-service capabilities;
- provide secure recovery.

## Layers

1. UEFI Secure Boot.
2. Trusted bootloader and kernel.
3. Signed OCI image.
4. SELinux enforcing mode.
5. Flatpak sandboxing.
6. Permission portals.
7. systemd unit hardening.
8. LUKS2 for persistent data.
9. TPM as optional key protection.
10. Signed repositories and registries.

## Threat model

At minimum, describe:

- registry compromise;
- signing-key theft;
- a malicious Flatpak;
- a malicious USB device;
- physical theft of the computer;
- a defective update;
- privilege escalation through a system service;
- lock-screen bypass;
- boot-chain modification;
- loss of access to encrypted data.

## Keys

Developer, testing, and production keys must be separate. The stable key must not be available to ordinary CI without additional controls.
