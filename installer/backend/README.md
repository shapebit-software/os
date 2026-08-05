# Installer backend

The planned privileged backend validates installation plans and performs only
explicitly modeled operations.

Initial interface:

1. `probe-disks`
2. `validate-plan`
3. `plan --dry-run`
4. transaction-log persistence
5. operations restricted to loop devices and QEMU disks

The backend must validate block-device identity and state immediately before a
destructive operation. It must never execute arbitrary commands supplied by the
frontend.
