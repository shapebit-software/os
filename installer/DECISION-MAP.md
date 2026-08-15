# Installer decision map

This document maps every planned initial ShapeBit OS installation operation to
the Architecture Decision Record that authorizes its product policy. It does
not create policy and does not override an ADR.

An operation may be implemented only within its primary ADR. Supporting ADRs
add constraints but do not transfer ownership. Adding an installer operation
requires adding it to this map and either identifying an accepted primary ADR
or recording the unresolved decision in the parent repository's work queue.

## Status and gates

`Accepted` means the operation has an accepted policy owner. `Proposed gate`
means the operation is mapped, but production behavior must not be treated as
settled until the named ADR is accepted or superseded.

Three gates remain:

- [ADR-0002] for ownership and mutation of installed filesystem paths;
- [ADR-0006] for the signed manifest and immutable release identity; and
- [ADR-0013] for the post-shim boot chain and TPM2 authorization policy.

These gates do not prevent protocol mocks or non-destructive UI work. They do
prevent claiming a production-ready real-disk installation path.

## Cross-cutting contract

| Operation | Primary authority | Supporting constraints | Status |
|---|---|---|---|
| Render the installer in an unprivileged Dioxus frontend | [ADR-0010] | [ADR-0035] | Accepted |
| Execute storage, boot, account, and configuration work in the privileged backend | [ADR-0010] | [ADR-0035] | Accepted |
| Exchange ordinary requests, responses, events, and errors | [ADR-0035] | [ADR-0010] | Accepted |
| Transfer passwords and generated recovery material | [ADR-0036] | [ADR-0011], [ADR-0012], [ADR-0039] | Accepted |
| Run a mock backend and non-destructive plan validation | [ADR-0035] | [ADR-0010] | Accepted |
| Advance, cancel, stop, retry, resume, or fail one installation transaction | [ADR-0037] | [ADR-0036], [ADR-0038] | Accepted |
| Record safe installer failures and diagnostic references | [ADR-0037] | [ADR-0031], [ADR-0035] | Accepted |
| Classify hardware evidence after installation testing | [ADR-0014] | [ADR-0033] | Accepted |

## `validating`

| Operation | Primary authority | Supporting constraints | Status |
|---|---|---|---|
| Probe one capability snapshot | [ADR-0035] | [ADR-0014] | Accepted |
| Report installer and target release versions and digests | [ADR-0035] | [ADR-0006] | Proposed gate: ADR-0006 |
| Detect UEFI, Secure Boot, and TPM2 availability | [ADR-0035] | [ADR-0012], [ADR-0013] | Proposed gate: ADR-0013 |
| Enumerate disks and issue opaque disk identifiers | [ADR-0038] | [ADR-0035] | Accepted |
| Exclude the installer medium, ambiguous devices, and unsafe active disks | [ADR-0038] | [ADR-0016] | Accepted |
| Allow an eligible internal or external whole-disk target | [ADR-0038] | [ADR-0016] | Accepted |
| Validate minimum capacity and protected reserves | [ADR-0028] | [ADR-0016], [ADR-0035] | Accepted |
| Collect locale, time zone, keyboard layout, and computer name | [ADR-0035] | [ADR-0002] | Proposed gate: ADR-0002 |
| Collect the first owner's user name and display name | [ADR-0035] | [ADR-0011] | Accepted |
| Confirm and transfer the owner password | [ADR-0036] | [ADR-0011] | Accepted |
| Detect connectivity and scan visible Wi-Fi networks | [ADR-0035] | [ADR-0021] | Accepted |
| Connect to optional installer Wi-Fi or skip it | [ADR-0035] | [ADR-0036] | Accepted |
| Preserve only an explicitly requested installer-created Wi-Fi profile | [ADR-0035] | [ADR-0011], [ADR-0021] | Accepted |
| Validate the complete effective plan in the backend | [ADR-0035] | [ADR-0037], [ADR-0038] | Accepted |
| Invalidate stale storage capabilities while preserving unrelated form values | [ADR-0038] | [ADR-0035] | Accepted |
| Present the final full-disk erase warning and obtain acknowledgements | [ADR-0038] | [ADR-0016] | Accepted |
| Issue and consume a one-use destructive confirmation token | [ADR-0038] | [ADR-0037] | Accepted |

## `preparing`

| Operation | Primary authority | Supporting constraints | Status |
|---|---|---|---|
| Select the exact ShapeBit bootc image by immutable release identity | [ADR-0006] | [ADR-0001], [ADR-0035] | Proposed gate: ADR-0006 |
| Acquire required image and boot artifacts without making Internet a completion requirement | [ADR-0037] | [ADR-0001], [ADR-0035] | Accepted |
| Stage bounded input secrets only in protected memory | [ADR-0036] | [ADR-0037] | Accepted |
| Revalidate target identity, eligibility, active use, plan, and release digest | [ADR-0038] | [ADR-0035], [ADR-0037] | Accepted |
| Cancel without modifying the target | [ADR-0037] | [ADR-0036] | Accepted |

## `creating-storage`

| Operation | Primary authority | Supporting constraints | Status |
|---|---|---|---|
| Cross the destructive boundary and erase the selected complete disk | [ADR-0037] | [ADR-0016], [ADR-0038] | Accepted |
| Create the GPT and EFI System Partition | [ADR-0016] | [ADR-0008], [ADR-0015] | Accepted |
| Create the outer system LUKS2 volume | [ADR-0012] | [ADR-0016] | Accepted |
| Create the outer Btrfs filesystem and `@root`, `@state`, `@homes`, and `@recovery` | [ADR-0003] | [ADR-0016], [ADR-0029] | Accepted |
| Establish storage for independently encrypted user-home containers | [ADR-0011] | [ADR-0003], [ADR-0016] | Accepted |
| Apply the dynamic home pool, guarantee, and protected-reserve policy | [ADR-0028] | [ADR-0016] | Accepted |
| Avoid installer-created Btrfs snapshots and a snapshot subvolume | [ADR-0029] | [ADR-0003] | Accepted |
| Use zram and create no unencrypted persistent swap | [ADR-0012] | [ADR-0016] | Accepted |
| Establish and synchronize the secret-free transaction journal and checkpoints | [ADR-0037] | [ADR-0036] | Accepted |

## `installing-system`

| Operation | Primary authority | Supporting constraints | Status |
|---|---|---|---|
| Install the Fedora-derived ShapeBit bootc image | [ADR-0001] | [ADR-0006] | Proposed gate: ADR-0006 |
| Verify that installed content matches the selected immutable release | [ADR-0006] | [ADR-0001], [ADR-0037] | Proposed gate: ADR-0006 |
| Populate image-owned paths and the writable configuration/state boundaries | [ADR-0002] | [ADR-0001], [ADR-0003] | Proposed gate: ADR-0002 |
| Install the Microsoft-signed ShapeBit shim for production | [ADR-0015] | [ADR-0013] | Proposed gate: ADR-0013 |
| Install signed boot manager and UKIs and establish their trust chain | [ADR-0013] | [ADR-0015] | Proposed gate: ADR-0013 |
| Install the self-contained signed recovery UKI outside normal deployment rotation | [ADR-0008] | [ADR-0013], [ADR-0016] | Proposed gate: ADR-0013 |
| Keep production and development signing material and trust domains separate | [ADR-0015] | [ADR-0033] | Accepted |

## `configuring`

| Operation | Primary authority | Supporting constraints | Status |
|---|---|---|---|
| Persist locale, time zone, keyboard layout, and computer name | [ADR-0035] | [ADR-0002] | Proposed gate: ADR-0002 |
| Enroll and verify TPM2 automatic unlock for the system volume | [ADR-0013] | [ADR-0012], [ADR-0015] | Proposed gate: ADR-0013 |
| Generate and enroll an independent device recovery key | [ADR-0012] | [ADR-0036], [ADR-0039] | Accepted |
| Create the first human owner as a `systemd-homed` account | [ADR-0011] | [ADR-0016], [ADR-0036] | Accepted |
| Create the owner's LUKS2 home with Btrfs inside | [ADR-0011] | [ADR-0016], [ADR-0028] | Accepted |
| Enroll the owner password without placing it in the plan or journal | [ADR-0011] | [ADR-0036] | Accepted |
| Generate and enroll an independent first-home recovery key | [ADR-0011] | [ADR-0036], [ADR-0039] | Accepted |
| Save requested installer Wi-Fi inside the first owner's encrypted profile | [ADR-0035] | [ADR-0011], [ADR-0021] | Accepted |
| Avoid escrow, logging, diagnostics, or persistent installer storage of secrets | [ADR-0036] | [ADR-0011], [ADR-0012], [ADR-0031] | Accepted |

## `verifying` and completion

| Operation | Primary authority | Supporting constraints | Status |
|---|---|---|---|
| Verify GPT, LUKS2, Btrfs, keyslot, and storage identities | [ADR-0037] | [ADR-0003], [ADR-0011], [ADR-0012], [ADR-0016] | Accepted |
| Verify the installed image digest | [ADR-0037] | [ADR-0006] | Proposed gate: ADR-0006 |
| Verify signed UKIs, boot entries, recovery assets, and the production trust chain | [ADR-0013] | [ADR-0015], [ADR-0037] | Proposed gate: ADR-0013 |
| Verify TPM2 system unlock and device recovery-key unlock | [ADR-0037] | [ADR-0012], [ADR-0013] | Proposed gate: ADR-0013 |
| Verify first-owner activation and home recovery-key unlock | [ADR-0037] | [ADR-0011] | Accepted |
| Verify a requested saved Wi-Fi profile | [ADR-0037] | [ADR-0035] | Accepted |
| Synchronize and safely unmount target filesystems | [ADR-0037] | [ADR-0003] | Accepted |
| Present one offline Recovery Kit containing two independent keys | [ADR-0039] | [ADR-0011], [ADR-0012], [ADR-0036] | Accepted |
| Print, manually present, or export and verify an encrypted Recovery Kit file | [ADR-0039] | [ADR-0036] | Accepted |
| Replace unconfirmed recovery keys after an interrupted presentation | [ADR-0039] | [ADR-0011], [ADR-0012], [ADR-0037] | Accepted |
| Require acknowledgement of the current kit before completion | [ADR-0039] | [ADR-0037] | Accepted |
| Write the complete marker, emit `completed`, and remove the journal | [ADR-0037] | [ADR-0039] | Accepted |
| Treat completion as disk-state verification rather than proof of first boot | [ADR-0037] | [ADR-0033] | Accepted |

## Explicitly outside the initial installer

| Excluded operation | Authority |
|---|---|
| Manual partitioning, partition shrinking, and same-disk dual boot | [ADR-0016] |
| Unencrypted disk-backed swap and first-release hibernation | [ADR-0012] |
| Managed snapshots or snapshot-based installer rollback | [ADR-0029] |
| Automatic data migration during fresh installation | [ADR-0004] |
| Treating rollback, backup, reset, and erase as one operation | [ADR-0005] |
| Proving a successful first physical boot from installer completion alone | [ADR-0033], [ADR-0037] |

[ADR-0001]: https://github.com/shapebit-software/os/blob/main/docs/decisions/ADR-0001-fedora-bootc.md
[ADR-0002]: https://github.com/shapebit-software/os/blob/main/docs/decisions/ADR-0002-filesystem-ownership.md
[ADR-0003]: https://github.com/shapebit-software/os/blob/main/docs/decisions/ADR-0003-btrfs-system-state.md
[ADR-0004]: https://github.com/shapebit-software/os/blob/main/docs/decisions/ADR-0004-data-migrations-and-rollback.md
[ADR-0005]: https://github.com/shapebit-software/os/blob/main/docs/decisions/ADR-0005-recovery-operation-semantics.md
[ADR-0006]: https://github.com/shapebit-software/os/blob/main/docs/decisions/ADR-0006-signed-release-manifest.md
[ADR-0008]: https://github.com/shapebit-software/os/blob/main/docs/decisions/ADR-0008-independent-recovery.md
[ADR-0010]: https://github.com/shapebit-software/os/blob/main/docs/decisions/ADR-0010-dioxus-installer.md
[ADR-0011]: https://github.com/shapebit-software/os/blob/main/docs/decisions/ADR-0011-per-user-encrypted-homes.md
[ADR-0012]: https://github.com/shapebit-software/os/blob/main/docs/decisions/ADR-0012-encrypted-system-volume.md
[ADR-0013]: https://github.com/shapebit-software/os/blob/main/docs/decisions/ADR-0013-boot-trust-and-tpm-policy.md
[ADR-0014]: https://github.com/shapebit-software/os/blob/main/docs/decisions/ADR-0014-platform-and-hardware-validation.md
[ADR-0015]: https://github.com/shapebit-software/os/blob/main/docs/decisions/ADR-0015-microsoft-shim-and-trust-domains.md
[ADR-0016]: https://github.com/shapebit-software/os/blob/main/docs/decisions/ADR-0016-initial-installation-and-storage-profile.md
[ADR-0021]: https://github.com/shapebit-software/os/blob/main/docs/decisions/ADR-0021-network-ownership-and-privacy.md
[ADR-0028]: https://github.com/shapebit-software/os/blob/main/docs/decisions/ADR-0028-capacity-and-low-space-policy.md
[ADR-0029]: https://github.com/shapebit-software/os/blob/main/docs/decisions/ADR-0029-no-managed-snapshots.md
[ADR-0031]: https://github.com/shapebit-software/os/blob/main/docs/decisions/ADR-0031-diagnostic-reports-and-consent.md
[ADR-0033]: https://github.com/shapebit-software/os/blob/main/docs/decisions/ADR-0033-simple-test-evidence.md
[ADR-0035]: https://github.com/shapebit-software/os/blob/main/docs/decisions/ADR-0035-minimal-installer-protocol.md
[ADR-0036]: https://github.com/shapebit-software/os/blob/main/docs/decisions/ADR-0036-one-shot-installer-secret-channel.md
[ADR-0037]: https://github.com/shapebit-software/os/blob/main/docs/decisions/ADR-0037-installer-transaction-lifecycle.md
[ADR-0038]: https://github.com/shapebit-software/os/blob/main/docs/decisions/ADR-0038-installer-disk-identity-and-confirmation.md
[ADR-0039]: https://github.com/shapebit-software/os/blob/main/docs/decisions/ADR-0039-recovery-kit-presentation-and-lifecycle.md
