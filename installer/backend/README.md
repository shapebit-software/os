# Installer backend

The planned privileged backend validates installation plans and performs only
explicitly modeled operations.

Initial interface:

1. `probe-disks`
2. `validate-plan`
3. `plan --dry-run`
4. transaction-log persistence
5. operations restricted to loop devices and QEMU disks

The user-enrollment path creates human accounts through `systemd-homed`, enrolls
the password through a short-lived secret channel, and generates a separate
recovery key. Neither secret may enter the plan or transaction log.

The storage path creates the system LUKS2 volume, enrolls TPM2 automatic unlock,
generates a separate device recovery key, and verifies both normal and recovery
boot paths. Disk-backed swap is rejected unless an explicit encrypted policy is
present; the first release uses zram.

For initial-owner provisioning, the backend returns the independently generated
device and home recovery keys through one short-lived Recovery Kit response.
The response is never part of `InstallationPlan`, persistent transaction state,
logs, diagnostics, or analytics. Acknowledging presentation does not prove
external storage and must not be recorded as cryptographic verification.

Recovery-key replacement must enroll and test the new keyslot before revoking
the old keyslot. Device and home recovery keys are replaced independently.

The backend must validate block-device identity and state immediately before a
destructive operation. It must never execute arbitrary commands supplied by the
frontend.
