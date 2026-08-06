# ADR-0013: Boot Trust and TPM2 Unlock Policy

**Status:** Proposed
**Date:** 2026-08-05
**Last updated:** 2026-08-06

## Context

ShapeBit OS needs an encrypted system volume that unlocks without a second
password prompt. The TPM2 must release its LUKS2 key only to an approved boot
chain, while routine system updates and rollback to the previous deployment
continue to work.

Binding the TPM2 key to exact kernel measurements would break automatic unlock
after every update. Trusting Secure Boot alone would authenticate EFI programs
but would not bind the encrypted deployment to its expected boot artifacts.
The design also needs explicit recovery, key rotation, and compromise
procedures before it can be treated as production security.

## Options considered

1. Bind the LUKS2 key directly to fixed PCR values.
2. Bind it to Secure Boot state plus a signed, update-compatible PCR policy.
3. Do not use TPM2 automatic unlock and request a system passphrase at boot.

## Decision

Use option 2 for the supported production configuration.

### Boot chain

- Use UEFI Secure Boot and `systemd-boot`.
- Boot signed Unified Kernel Images (UKIs) as systemd-boot Type #2 entries.
- Do not maintain a separate unsigned kernel, initramfs, or kernel command line
  on the EFI System Partition (ESP).
- Use bootc sealed-image deployment integrity for production images: the signed
  UKI carries the expected composefs digest, and fs-verity verification is
  required at boot.
- Keep the ESP unencrypted, minimal, and free of private keys and user data.
- The recovery environment follows the same Secure Boot and UKI requirements,
  with a distinct release profile.

### TPM2 authorization

- Enroll a TPM2 LUKS2 keyslot for normal system-volume activation.
- Bind the slot directly to PCR 7, which represents Secure Boot policy state.
- Authorize PCR 11 with signed expected measurements for approved UKIs instead
  of sealing to one fixed PCR 11 value.
- Embed the PCR public key and signature in each approved UKI.
- Restrict authorization to the initrd phase used to unlock the system volume.
- Do not bind PCR 0 or PCR 2 by default; ordinary firmware and option-ROM
  updates would make recovery unnecessarily frequent.
- Add PCR 14 only if a later generic-PC design uses shim and MOK policy.

The exact `systemd-cryptenroll`, `systemd-measure`, and `ukify` arguments are an
implementation detail that must be pinned to, and tested with, the systemd
version in the target Fedora bootc image. ShapeBit OS must not depend on newer
systemd policy features until they exist in that image.

### Update and rollback window

- A promoted deployment must contain a Secure Boot-signed UKI and a valid
  signed PCR 11 policy before it may be staged.
- Pre-reboot validation must prove that TPM2 unlock authorizes both the pending
  deployment and the retained rollback deployment.
- The current accepted deployment, one pending deployment, and one previous
  accepted deployment form the default authorized boot window.
- Artifacts leave the ESP and authorized rollback set only after they are no
  longer required by retention policy.
- A failed trial boot must be able to select the previous signed UKI without a
  recovery-key prompt.

This policy does not provide absolute anti-rollback protection. Any retained
artifact signed by a still-trusted key remains bootable. The prototype uses a
bounded rollback window; signed release blocklists prevent an old image from
being staged again but cannot invalidate an offline retained UKI.

Every signed release manifest reserves a non-decreasing `security_epoch`. The
epoch changes only at an explicit security barrier, not for every ordinary
release, so current and rollback deployments may share an epoch. It is release
metadata until a later anti-rollback ADR defines its cryptographic binding to a
TPM2 NV policy.

Strong TPM-backed anti-rollback may be deferred during disposable prototype and
VM work, but must be designed, implemented, and validated before public alpha
or the first persistent production-device provisioning, whichever happens
first. A device provisioned earlier must not be advertised as supporting strong
anti-rollback. Migrating such a device must invalidate the old TPM2 enrollment;
deleting only its current LUKS2 keyslot is insufficient because an attacker may
have retained an older LUKS2 header.

### Key roles

Use separate keys for separate trust domains:

| Key | Purpose | Production custody |
|---|---|---|
| UEFI Platform Key and KEK | firmware ownership and authorized `db` changes | offline or hardware-backed provisioning authority |
| Secure Boot `db` key | sign systemd-boot and UKIs | restricted release-signing service backed by an HSM |
| PCR policy key | authorize expected PCR 11 measurements | separate restricted HSM-backed service |
| OCI/release-manifest key | authorize downloaded release metadata and content | release infrastructure, separate from boot keys |
| Device recovery key | unlock one device's system LUKS2 volume | device owner only |

Production private keys must never be stored in Git, copied into an OCI image,
written to the installed disk, or exposed to general-purpose CI jobs. Builds
may receive a signing operation or short-lived secret from controlled signing
infrastructure. Development uses visibly distinct disposable test keys.

ShapeBit's Secure Boot `db` certificate authorizes ShapeBit OS releases. Who
owns a device's firmware Platform Key is a hardware-distribution decision and
does not require reuse of any ShapeBit release-signing private key.

### Hardware scope

- The first supported path is ShapeBit reference hardware and virtual machines
  whose Secure Boot trust can be provisioned explicitly.
- Generic PCs with existing OEM or Microsoft trust are not production-supported
  by this ADR. Replacing their keys can affect dual boot and third-party EFI
  components.
- A future generic-PC path must separately decide whether to use shim and
  Microsoft signing, preserve owner-managed keys, or require custom enrollment.

### Recovery, rotation, and revocation

- Every device keeps the independent high-entropy recovery key required by
  [ADR-0012](ADR-0012-encrypted-system-volume.md).
- Recovery-key boot must be tested after simulated PCR mismatch, Secure Boot
  database change, TPM clear, and motherboard replacement.
- Secure Boot key rotation uses an authenticated firmware update with an
  overlap period in which the old rollback artifact and the new release remain
  bootable. TPM enrollment is refreshed before a PCR 7-changing key update.
- PCR policy-key rotation creates a new TPM2 enrollment while the old policy or
  device recovery key can still unlock the volume.
- Compromise of the Secure Boot signing key requires stopping release,
  publishing a replacement trust update, revoking the compromised certificate
  where supported, and replacing affected boot artifacts.
- Compromise of the PCR policy key requires a new policy key and device TPM2
  re-enrollment; revoking only the Secure Boot key is insufficient.
- Recovery media may unlock the system volume only after the owner supplies the
  device recovery key. It must not automatically unlock per-user homes.

## Rationale

A signed PCR policy separates the stable TPM2 trust anchor from measurements
that legitimately change on every OS update. PCR 7 detects changes to Secure
Boot configuration, while PCR 11 ties activation to an approved UKI. Signed
UKIs and sealed deployment integrity cover the otherwise-unencrypted boot
assets and bind them to the expected system deployment.

Separating key roles limits the effect of one compromised service. Retaining a
device recovery key prevents a firmware update, TPM failure, or key rotation
from permanently destroying access to the encrypted system volume.

## Positive consequences

- Normal startup has no system-volume password prompt.
- Approved updates and the previous rollback deployment remain automatically
  unlockable.
- Modified boot assets or an unauthorized UKI do not receive the TPM2 key.
- Production, development, boot, PCR-policy, and release-metadata trust are
  independently rotatable.
- Recovery remains possible after TPM2 or motherboard failure.

## Negative consequences

- Provisioning requires Secure Boot key enrollment on reference targets.
- Firmware trust updates can change PCR 7 and require coordinated TPM2
  re-enrollment.
- A retained, still-signed old release remains bootable within the rollback
  window.
- HSM-backed signing and revocation procedures add release-infrastructure work.
- Generic-PC support needs another decision and may require external signing.

## Required validation

Before accepting this ADR, demonstrate in QEMU with OVMF and swtpm, then on
reference hardware:

1. boot of a signed UKI with Secure Boot enabled;
2. refusal to boot a modified or untrusted UKI;
3. TPM2 unlock of the current deployment without a system passphrase;
4. refusal to auto-unlock after unauthorized PCR 7 or PCR 11 changes;
5. update from image A to B and automatic rollback from B to A;
6. recovery-key unlock after TPM clear and after a Secure Boot trust change;
7. Secure Boot `db` and PCR policy-key rotation without data loss;
8. confirmation that production private keys are absent from images, ESPs,
   logs, build output, and general CI workers;
9. sealed deployment verification with fs-verity required;
10. power-loss testing during staging and trust-policy rotation.

## Re-evaluation criteria

- ShapeBit OS expands from controlled reference hardware to generic PCs.
- The target systemd or bootc release changes its supported TPM2 policy or
  sealed-image mechanism.
- The target systemd gains native composition of signed PCR and TPM2 NV-counter
  policies.
- Hibernation is introduced.
- Secure Boot or PCR policy key compromise occurs.

## References

- [bootc sealed-image key management](https://bootc.dev/blog/2026-may-05-sealed-images-key-management/)
- [bootc sealed-image building](https://bootc.dev/blog/2026-may-06-sealed-images-building/)
- [bootc sealed-image deployment verification](https://bootc.dev/blog/2026-may-07-sealed-images-deploying/)
- [systemd TPM2 PCR measurements](https://systemd.io/TPM2_PCR_MEASUREMENTS/)
