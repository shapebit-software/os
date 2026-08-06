# ShapeBit OS Temporary Continuation Note

**Recorded:** 2026-08-05
**Last updated:** 2026-08-06

This is a temporary, non-authoritative handoff note. The ADRs and architecture
documents remain authoritative. Delete this file after the work below has been
implemented or moved into the normal project plan.

## Current decision state

- [ADR-0011](../decisions/ADR-0011-per-user-encrypted-homes.md) is accepted:
  each human user has a separate `systemd-homed` LUKS2 home, and one PAM login
  password both authenticates the user and unlocks the home.
- [ADR-0012](../decisions/ADR-0012-encrypted-system-volume.md) is accepted: the
  physical system root is LUKS2-encrypted and normally unlocked by TPM2, with a
  separate per-device recovery key.
- [ADR-0013](../decisions/ADR-0013-boot-trust-and-tpm-policy.md) is proposed and
  is the selected implementation candidate pending validation.

The proposed boot authorization is:

```text
PCR 7:  direct TPM2 binding to the UEFI Secure Boot policy
PCR 11: signed policy for approved UKIs and their boot phase
```

The intended boot path is:

```text
UEFI Secure Boot
→ signed systemd-boot
→ signed UKI and sealed deployment verification
→ PCR 7 + signed PCR 11 authorization
→ TPM2 unlocks the system LUKS2 volume
→ login surface
→ one user password authenticates and unlocks that user's home
```

Additional decisions already recorded:

- use signed UKI Type #2 boot entries instead of BLS entries;
- production sealed deployments carry the expected composefs digest and require
  fs-verity verification;
- zram is the default swap and disk-backed swap may never be plaintext;
- PCR 0 and PCR 2 are not used initially because they are too sensitive to
  firmware and hardware changes;
- PCR 14 is relevant only if a future generic-PC design uses shim/MOK;
- retain an independent system-volume recovery key;
- keep Secure Boot, PCR-policy, OCI/release, firmware-administration, and device
  recovery keys separate;
- support controlled ShapeBit reference hardware and VMs first;
- defer the generic-PC Secure Boot ownership/signing model;
- use a bounded rollback window during prototype development;
- reserve a signed, non-decreasing `security_epoch` in release manifests;
- design and implement TPM2-backed anti-rollback before public alpha or the
  first persistent production-device provisioning, whichever happens first;
- treat legacy TPM2 enrollment invalidation as a required migration step;
- do not claim that deleting only the current LUKS2 keyslot revokes a retained
  copy of an older LUKS2 header.

## Current implementation state

- The documentation has been reconciled around the encryption and boot-trust
  model, but the changes have not been committed in this session.
- The `image` submodule is still a Fedora bootc 44 console-image scaffold.
- No successful end-to-end image build, disk creation, Secure Boot, TPM2 unlock,
  UEFI boot, or TTY login is recorded yet.
- Signed UKIs, sealed deployment verification, Secure Boot provisioning,
  `systemd-homed`, and TPM2-backed system LUKS2 are not implemented yet.
- The installer remains a contract/backend scaffold rather than a working
  installer.
- The worktree already contains multiple documentation and submodule changes;
  inspect and preserve them before editing or committing.

## Resume here

1. Inspect the exact Fedora bootc 44 versions and supported interfaces for
   bootc sealed images, `ukify`, `systemd-measure`, `systemd-cryptenroll`, OVMF,
   and swtpm.
2. Define disposable development-key generation and storage. Never commit
   private Secure Boot or PCR-policy keys.
3. Build and boot a signed UKI under OVMF Secure Boot.
4. Create the system LUKS2 volume and enroll TPM2 authorization using direct
   PCR 7 binding plus a signed PCR 11 policy.
5. Prove automatic unlock and prove rejection after an unauthorized UKI or
   Secure Boot policy change.
6. Prove device-recovery-key unlock after TPM clear or policy mismatch.
7. Build images A and B; verify update to B and automatic rollback to A without
   requesting the recovery key.
8. Verify sealed deployment digest and required fs-verity enforcement.
9. Exercise Secure Boot and PCR-policy key rotation using development keys.
10. Record test evidence in project status and consider accepting ADR-0013 only
    after its required validation matrix passes.

## Still open

- exact command-line arguments supported by Fedora bootc 44 and its systemd
  version;
- boot-attempt counting and automatic selection of the accepted deployment;
- generic-PC trust model: shim/Microsoft signing, owner keys, or mandatory
  custom enrollment;
- exact TPM2 NV anti-rollback design and safe invalidation of prototype TPM2
  enrollments before persistent production provisioning;
- production HSM, signing-service, rotation, and revocation infrastructure;
- hibernation and encrypted resume design.

## Validation already completed for the documentation

- local Markdown links resolve;
- `git diff --check` passes;
- stale BLS, GRUB-choice, optional-TPM, fixed-PCR-policy, and explicit
  bootc/OSTree-backend assumptions were removed from active planning documents.
