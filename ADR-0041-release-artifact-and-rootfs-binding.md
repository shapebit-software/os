# ADR-0041: Release Artifact and Rootfs Binding

**Status:** Proposed
**Date:** 2026-08-17

## Context

ADR-0006 identifies exact release artifacts, but independent valid signatures
do not prove that an OCI image, UKI, composefs root, boot manager, and PCR policy
belong to the same build. ShapeBit must prevent a valid artifact from one release
from being combined with a different valid artifact.

Upstream bootc integration among its composefs backend, systemd-boot, and a
vendor-signed UKI is still evolving. ShapeBit therefore cannot treat complete
boot-artifact binding as an implicit property of bootc; it needs an explicit
contract and validation gate.

## Decisions established so far

### OCI identity

`artifacts.system_image.digest` identifies the per-architecture OCI image
manifest for OCI architecture `amd64`, corresponding to ShapeBit architecture
`x86_64`. It does not identify a mutable tag, a multi-architecture image index,
or only an OCI image configuration object. The selected OCI manifest in turn
identifies its exact config and layer descriptors.

### Rootfs as the boot-time join key

`rootfs.digest` is the boot-time join key between the system image and UKI:

- the release pipeline deterministically derives and verifies the composefs
  root from the exact `system_image` content;
- the final signed UKI contains the expected rootfs integrity digest;
- initrd selects only a deployment with that digest and requires fs-verity
  verification before switching to the real root; and
- any missing or unequal digest is a hard boot failure.

The final authoritative UKI is a separate release artifact and is excluded from
the content covered by the rootfs digest. The pipeline first produces the
rootfs and its digest, then builds and signs the UKI. This avoids a cycle in
which UKI bytes affect the digest embedded inside that same UKI.

The UKI does not embed `manifest_digest`. ADR-0006 already includes the UKI
digest in that manifest, so embedding the manifest digest in the UKI would also
create a self-referential build cycle. The signed release manifest instead
binds the OCI manifest, rootfs digest, and final UKI digest as peers.

The manifest represents this value as the separate `rootfs` object with
`format: composefs` and its SHA-512 digest. It is not placed in `artifacts`
because it has no separately downloaded object, size, or media type.

### Artifact media types

The system release manifest and the independently signed boot-stack manifest
use existing format media types rather than ShapeBit-specific role media types:

- `system_image`: `application/vnd.oci.image.manifest.v1+json`;
- `shim`: `application/vnd.microsoft.portable-executable`;
- `boot_manager`: `application/vnd.microsoft.portable-executable`;
- `system_uki`: `application/vnd.microsoft.portable-executable`.

The manifest object key identifies an artifact's role. The media type identifies
its byte format and does not duplicate that role. Consumers must therefore
validate both the expected role and the expected format; accepting a valid PE
file under the wrong role is forbidden.

### Independent device boot stack

Shim and the boot manager form one device-wide boot stack shared by all system
deployments. They are excluded from the system release manifest and described
by a separate signed boot-stack manifest that pins their exact digests, sizes,
and media types.

The boot stack has an independent lifecycle and moves only forward. Rolling
back a trial system deployment changes its UKI and rootfs selection but never
restores older shim or boot-manager bytes. This preserves boot security fixes
and avoids coupling a deployment rollback to shared EFI state.

A boot-stack update must remain capable of booting the accepted deployment and
the retained rollback deployment. ShapeBit must establish this compatibility
before changing shared EFI state. Compatibility validation and the
power-loss-safe installation transaction remain to be defined before this ADR
can be accepted.

### Boot-stack manifest

The boot-stack manifest is a closed UTF-8 JSON schema. Its top-level object
contains exactly `schema_version`, `boot_stack_version`, `architecture`,
`security_epoch`, and `artifacts`:

- `schema_version` is the integer `1`;
- `boot_stack_version` uses the same SemVer-compatible CalVer
  `year.month.revision` form as a system release;
- `architecture` is exactly `x86_64` in schema version 1;
- `security_epoch` uses the same non-negative decimal-string representation and
  global security-barrier meaning as the system release manifest; and
- `artifacts` contains exactly one `shim` and one `boot_manager` descriptor.

Each artifact descriptor contains exactly `digest`, `size`, and `media_type`,
using the same SHA-256 digest and decimal-string size syntax as ADR-0006. Both
media types are exactly `application/vnd.microsoft.portable-executable`.

The payload is serialized with RFC 8785 JCS and carried in DSSE with payload
type `application/vnd.shapebit.boot-stack-manifest.v1+json`. Signature entries,
key identifiers, signature thresholds, and the SHA-256 digest of the canonical
payload follow the release-manifest rules and D23's trust policy. The computed
boot-stack manifest digest is not stored inside its payload.

Human-readable example; the signed payload contains its JCS serialization:

```json
{
  "schema_version": 1,
  "boot_stack_version": "2026.8.0",
  "architecture": "x86_64",
  "security_epoch": "1",
  "artifacts": {
    "shim": {
      "digest": "sha256:<64 lowercase hexadecimal digits>",
      "size": "123456",
      "media_type": "application/vnd.microsoft.portable-executable"
    },
    "boot_manager": {
      "digest": "sha256:<64 lowercase hexadecimal digits>",
      "size": "123456",
      "media_type": "application/vnd.microsoft.portable-executable"
    }
  }
}
```

The payload has no timestamps, channel, download locations, component
requirements, compatibility ranges, annotations, or extension map. Mutable
distribution and rollout data remains separately authenticated and keyed by
the boot-stack manifest digest.

### Boot compatibility contract

Within one `security_epoch`, every newer boot stack must boot every
non-revoked ShapeBit system release from that epoch. Increasing
`boot_stack_version` alone must never break this compatibility. Only an
explicit global `security_epoch` transition may intentionally reject older
system releases.

Compatibility is a release qualification obligation rather than a version
range interpreted on each device. Before publication, ShapeBit must validate
the candidate shim and boot manager against the applicable non-revoked release
set in automated QEMU tests and the hardware gates defined by ADR-0014. A
device validates the signed manifest, architecture, epoch, artifact identities,
and formats; it does not solve a compatibility matrix or consume a compatibility
allowlist.

A published boot stack that violates this contract is a release failure and
must not be worked around by silently dropping an installed rollback
deployment.

### Boot-stack update ordering

A boot-stack update that remains in the current `security_epoch` may run as an
independent update before or after a system update, but only after the
compatibility qualification above succeeds. It does not alter the system trial
or acceptance state.

For an update to a higher `security_epoch`, the target system deployment first
completes its normal trial on the existing boot stack. The old epoch remains
authorized throughout that trial, preserving the rollback baseline. Only after
the target system is durably accepted does ShapeBit install the new boot stack,
advance the durable epoch barrier, and make older-epoch deployments
unbootable.

There is therefore a bounded post-acceptance transition in which the new system
is accepted but the old boot stack and epoch barrier are still active. The
transaction must record and resume this state. Failure after system acceptance
uses recovery and fix-forward completion; it never restores an older,
security-invalidated boot stack or reopens the system rollback guarantee.

This ordering deliberately accepts a short trial window in which the new system
still runs over the old boot stack. Avoiding that window would require a second
A/B lifecycle for the boot stack and would close the system rollback path before
the candidate had proved healthy.

### A/B boot-stack installation

The ESP holds two logical boot-stack slots. Each slot contains a matched shim
and boot-manager pair and has its own UEFI boot entry. Exactly one slot is the
durably active default; an update writes only the inactive slot.

The updater verifies the candidate manifest and artifacts before writing,
writes the complete inactive slot, flushes it, reads it back, and verifies its
size, digest, PE structure, architecture, and signatures. It then sets the
inactive slot's UEFI entry through `BootNext` for one boot without changing the
durable default.

The candidate slot is promoted only after it starts the expected accepted OS
deployment, that deployment confirms the running boot-stack identity matches
the candidate manifest, and the normal mandatory health contract succeeds.
Promotion durably makes the candidate UEFI entry the default and records its
manifest digest as active. An old slot is not offered as an automatic rollback
after promotion and may be overwritten by the next update.

If power is lost before `BootNext` is set, the existing default remains active.
If the candidate does not reach promotion after `BootNext` is consumed, the
next boot returns to the unchanged default slot. If power is lost during or
after promotion, the durable transaction record must select either completion
of the candidate promotion or recovery-assisted fix-forward; it must not copy
partially written files over the known-good slot.

For a higher-epoch transition, the durable epoch barrier advances only after
the candidate boot stack has booted successfully and become the durable
default. The old slot is then removed from normal firmware selection. D24 must
ensure that an old copied or manually selected stack cannot regain TPM-backed
authorization after the barrier advances.

### ESP paths and firmware fallback

ShapeBit uses these canonical ESP paths on x86-64:

```text
EFI/ShapeBit/slot-a/shimx64.efi
EFI/ShapeBit/slot-a/shapebit-bootx64.efi
EFI/ShapeBit/slot-b/shimx64.efi
EFI/ShapeBit/slot-b/shapebit-bootx64.efi
EFI/BOOT/BOOTX64.EFI
EFI/BOOT/shapebit-bootx64.efi
```

The two `EFI/ShapeBit` directories are the transaction slots and have distinct
UEFI boot entries. ShapeBit builds its shim with
`shapebit-bootx64.efi` as the default second-stage filename, so every shim loads
the boot manager from its own directory. ShapeBit does not disguise
systemd-boot as `grubx64.efi` and does not install `MokManager.efi`,
`fallback.efi`, or `BOOT.CSV`; MOK is outside the supported trust model.

`EFI/BOOT/BOOTX64.EFI` is a byte-identical copy of the Microsoft-signed
ShapeBit shim from the last promoted stack, and its adjacent
`shapebit-bootx64.efi` is the matching signed boot manager. This generic UEFI
fallback pair permits boot after firmware variables are lost without adding a
third independently versioned stack.

The updater refreshes the generic fallback pair only after a slot promotion.
It writes and verifies the boot manager before replacing `BOOTX64.EFI`; an
interrupted fallback refresh never changes the promoted slot or its firmware
entry and is resumed from the durable transaction record. For an epoch
transition, the fallback pair must match and verify against the promoted
boot-stack manifest before the durable epoch barrier advances.

### Recovery reconstruction

Recovery may inspect the ESP, both boot-stack slots, signatures, manifests,
transaction state, and UEFI entries without authentication. Any repair that
writes the ESP or firmware variables requires an administrator credential or
the device recovery key under ADR-0005.

Recovery reconstructs only artifacts identified by a valid signed boot-stack
manifest; it does not offer arbitrary EFI-file selection. Using verified local
cache or freshly downloaded artifacts, it may rebuild a damaged slot, recreate
the two UEFI slot entries, restore the generic fallback pair, or finish an
interrupted promotion. Every reconstructed object is read back and verified
before its entry is enabled.

Internal recovery can perform this work only while a trusted internal recovery
UKI and a usable boot path remain. If the ESP is unreadable or no internal boot
path survives, the user starts the same signed ShapeBit recovery environment
from external USB media. After authorization, external recovery may recreate
the ESP and its boot metadata while preserving the encrypted system volume and
per-user homes. Reformatting or repartitioning beyond the ESP is not implicit in
boot repair.

### Verification at each trust boundary

ShapeBit revalidates artifacts at every trust boundary rather than treating a
previous success flag as proof that stored bytes remain valid.

The release build performs these operations in dependency order:

1. validate the architecture-specific OCI manifest, configuration, layers,
   media types, sizes, and digests;
2. deterministically produce the composefs root and verify its fs-verity
   identity;
3. build the UKI with the exact rootfs parameter and embedded PCR policy;
4. validate its PE structure and architecture, sign it for Secure Boot, and
   verify the final signed bytes; and
5. construct and sign the release manifest last, only after every referenced
   digest and size is final.

Boot-stack publication similarly validates and signs shim and the boot manager
before constructing and signing their manifest.

During installation or staging, the trusted client first authenticates the
release manifest and checks revocation, architecture, epoch, platform, and tool
requirements. It then retrieves descriptors by immutable digest, verifies
their sizes, media types, bytes, and nested OCI graph, produces the local
composefs deployment, and proves its rootfs identity. It validates the UKI's
digest, PE machine type, Secure Boot signature, required sections, embedded
rootfs parameter, and PCR policy. Critical objects are flushed, read back, and
verified again. The updater may create a bootable `pending` entry only after
all checks and required TPM authorization preflight succeed.

At every boot, firmware, shim, and the boot manager enforce the Secure Boot
chain to the selected UKI. The signed UKI supplies the measured command line
and PCR policy. Initrd requires exactly one matching local deployment and
active fs-verity verification before TPM-backed unlock and switching root.
Boot does not rehash the complete rootfs eagerly; fs-verity verifies data as it
is read. Userspace then verifies expected release identity and runs the normal
health contract before trial acceptance or boot-stack promotion.

Recovery trusts neither a validation flag nor unchecked bytes left by the
installed system. Starting from its own signed image, it repeats manifest,
policy, artifact, and read-back validation before enabling any reconstructed
boot path.

### Signed UKI location

The UKI embeds the expected digest exactly once in its signed `.cmdline`
section as:

```text
rd.shapebit.rootfs=sha512:<128 lowercase hexadecimal digits>
```

The value is not secret. With Secure Boot enabled, `systemd-stub` ignores an
external attempt to replace an embedded command line. The `.cmdline` contents
are covered by the UKI Secure Boot signature and PCR 11 measurement.

Initrd rejects a missing, duplicate, malformed, unsupported-algorithm, or
unequal parameter as a hard failure. It must resolve exactly one local
deployment with that digest, require active fs-verity verification, and only
then switch to the real root. Command-line additions must not select or replace
the deployment identity.

### PCR policy inside UKI

PCR policy is not a separate release artifact. Every `system_uki` embeds the
standard UKI `.pcrsig` section containing signed expected PCR 11 values and the
`.pcrpkey` section containing the corresponding public key. `systemd-measure`
produces the policy signatures. The UKI specification deliberately excludes
`.pcrsig` from PCR 11 measurement, avoiding a signature self-reference.

The release manifest binds the complete signed UKI digest, and the UKI carries
the PCR policy needed to authorize it. Replacing the PCR policy or public key
therefore creates a new UKI artifact and requires a new Secure Boot signature
and release manifest. ShapeBit does not support a separately replaceable PCR
policy sidecar in schema version 1.

## Boundaries

This ADR owns D22's artifact graph, equality checks, boot-time rootfs selection,
and failure behavior. ADR-0006 owns the manifest schema. ADR-0013 owns Secure
Boot and TPM2 authorization policy. D23 owns signing-key operations and trust
thresholds.

## Required acceptance evidence

This ADR remains `Proposed` until the complete design is demonstrated rather
than inferred from component documentation.

The automated x86-64 QEMU, OVMF, Secure Boot, and software-TPM suite must cover
installation, staging, trial, acceptance, rollback, same-epoch boot-stack
updates, higher-epoch transitions, both transaction slots, the generic UEFI
fallback path, internal recovery repair, and external recovery of a lost ESP.

Fault injection must interrupt power after every persistent checkpoint in
system staging and the A/B boot-stack transaction, including slot writing,
read-back verification, `BootNext`, candidate boot, promotion, generic fallback
refresh, and epoch-barrier advancement. Every restart must reach exactly one
safe outcome: the unchanged known-good state, resumable forward completion, or
signed recovery. It must never select a partial or mismatched artifact set.

Negative tests must independently corrupt, truncate, substitute, or mismatch
the OCI manifest or layer, composefs root, UKI and its rootfs parameter or PCR
policy, shim, boot manager, signed manifests, and durable transaction record.
Every mutation must fail closed at the earliest applicable trust boundary.

At least one laptop carrying `Officially-tested` evidence for the exact
ShapeBit release, hardware configuration, and firmware version must complete
the corresponding physical UEFI, Secure Boot, TPM2, update, interruption,
fallback, and recovery flow. This is an evidence gate, not a reference-laptop
designation. Test records must identify the test cases and exact manifest
digests under ADR-0033. ADR-0014 continues to own recurring release-level
hardware gates.

## Related decisions

- [ADR-0006](ADR-0006-signed-release-manifest.md)
- [ADR-0007](ADR-0007-trial-boot-and-acceptance.md)
- [ADR-0013](ADR-0013-boot-trust-and-tpm-policy.md)
- [ADR-0015](ADR-0015-microsoft-shim-and-trust-domains.md)
- [ADR-0033](ADR-0033-simple-test-evidence.md)
- [ADR-0040](ADR-0040-forward-only-migrations-and-trial-bounded-rollback.md)

## References

- [bootc UKI/systemd-boot tracker](https://github.com/bootc-dev/bootc/issues/806)
- [systemd TPM2 PCR measurements](https://systemd.io/TPM2_PCR_MEASUREMENTS/)
- [UAPI Unified Kernel Image specification](https://uapi-group.org/specifications/specs/unified_kernel_image/)
- [systemd-stub](https://man7.org/linux/man-pages/man7/systemd-stub.7.html)
- [Linux fs-verity documentation](https://docs.kernel.org/filesystems/fsverity.html)
