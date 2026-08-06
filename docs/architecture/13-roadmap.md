# 13. Roadmap

**Status:** Draft

## M0 — documentation

- product vision;
- architecture;
- image model;
- filesystem;
- updates;
- security;
- development workflow.

## M1 — bootable prototype

- Fedora bootc;
- QEMU;
- OVMF Secure Boot;
- signed UKIs;
- TPM2 automatic system-volume unlock;
- console login;
- per-user encrypted home activation;
- networking;
- branding.

## M1.5 — Dioxus installer prototype

- Dioxus frontend;
- shared installation-plan model;
- dry run;
- backend operating on a virtual disk;
- console-only image installation;
- boot to a TTY.

## M2 — updates

- custom registry;
- image versioning;
- update;
- rollback;
- diagnostic report.

## M3 — CI/CD

- automated build;
- controlled boot and policy signing;
- boot test;
- nightly;
- manifest and SBOM.

## M4 — first custom components

- updater;
- onboarding;
- settings shell;
- platform services.

## M5 — compositor

- Rust + Smithay;
- nested mode;
- basic windows and input;
- session in a VM.

## M6 — custom desktop

- compositor;
- shell;
- launcher;
- panel;
- notifications;
- lock screen.

## M7 — hardware and installation

- installer hardening;
- encryption;
- production key rotation and revocation;
- TPM2-backed anti-rollback and legacy-enrollment migration;
- recovery;
- reference hardware.

## M8 — developer preview

The team can test the system daily.

## M9 — public alpha

- no persistent production device remains on the prototype TPM2 policy;
- stable update channel;
- limited hardware matrix;
- documentation;
- issue handling;
- factory reset.
