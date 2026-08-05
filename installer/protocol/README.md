# Installer protocol

This planned Rust crate defines the data exchanged by the Dioxus UI, backend,
and tests.

Initial types:

- `InstallationPlan`
- `DiskInfo`
- `EncryptionPlan`
- `FilesystemPlan`
- `InstallationStep`
- `InstallationEvent`
- `InstallerError`

Messages must be serializable and versioned. `InstallationPlan` must not contain
LUKS passwords or other secrets; secrets require a separate short-lived
channel.
