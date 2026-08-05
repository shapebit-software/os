# shapebit-installer-protocol

Shared Rust crate for the Dioxus UI, backend, and tests.

Initial types:

- `InstallationPlan`
- `DiskInfo`
- `EncryptionPlan`
- `FilesystemPlan`
- `InstallationStep`
- `InstallationEvent`
- `InstallerError`

The plan must not contain a LUKS password or other secrets. Secrets will be passed through a separate, short-lived channel.
