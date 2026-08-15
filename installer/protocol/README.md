# Installer protocol

This planned Rust crate defines the data exchanged by the Dioxus UI, backend,
and tests.

Initial types:

- `InstallationPlan`
- `DiskInfo`
- `EncryptionPlan`
- `SystemEncryptionPlan`
- `SwapPlan`
- `UserPlan`
- `HomeStoragePlan`
- `FilesystemPlan`
- `InstallationStep`
- `InstallationEvent`
- `InstallerError`

Messages must be serializable and versioned. `InstallationPlan` must not contain
LUKS passwords or other secrets; secrets require a separate short-lived
channel.

`HomeStoragePlan` selects `systemd-homed` with per-user LUKS2 storage for human
accounts. It carries policy and sizing information, never the login password or
recovery key.

`SystemEncryptionPlan` selects TPM2-unlocked LUKS2 plus device recovery-key
enrollment. `SwapPlan` defaults to zram and may never select unencrypted
disk-backed swap.

The secret-enrollment channel may return a versioned Recovery Kit payload for
initial-owner provisioning. It contains two independently generated secrets:
the device recovery key and that owner's home recovery key. The payload is
ephemeral and must not be embedded in serializable plans, installation events,
errors, persistent state, or diagnostic representations. Additional-user
enrollment returns only that user's home recovery key.

The initial-owner payload represents one self-contained offline document with a
common header, separately labeled device and home key records, and an integrity
checksum. QR, print, and encrypted-file encodings preserve that logical content;
none contains a URL or server-side retrieval reference.
