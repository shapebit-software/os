The system downloads and verifies updates in the background.

A system update proceeds as:

download
   ↓
verify manifest and artifacts
   ↓
stage deployment
   ↓
stage signed UKI
   ↓
user restart
   ↓
trial boot
   ↓
health verification
   ├── fail → rollback
   └── pass → accept

The OS never makes a downloaded release bootable until its signed manifest, artifact identities, UKI, rootfs binding, and TPM authorization have been validated.

Updates do not force the user to terminate an active desktop session.