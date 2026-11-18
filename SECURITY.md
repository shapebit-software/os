# Security

## Reporting a vulnerability

Report a vulnerability privately, never in a public issue:

- On GitHub: **Security > Report a vulnerability** in this repository, or
- By email: hello@shapebit.software, with "Security" in the subject.

Say what is affected, how to reproduce it, and what it lets an attacker do.
You get an answer within 7 days. Once a fix is released, the advisory names
you, unless you prefer otherwise.

## Supported versions

Only the current release, `ghcr.io/shapebit-software/os:stable`, gets security
fixes. Installed systems update to it on their own (Settings > Updates).

## Design

- Disk encryption, the boot chain, and the TPM policy:
  [packages/boot](packages/boot/README.md); encrypted homes:
  [packages/homes](packages/homes/README.md).
- Signing keys, their protection and rotation:
  [release/keys.md](release/keys.md).
- Releases, withdrawal, and what must happen before a public release:
  [release](release/README.md).
- The third-party Hyprland repository:
  [packages/repositories](packages/repositories/README.md#hyprland).
- The assistant's permissions: [packages/assistant](packages/assistant/README.md#rules).
