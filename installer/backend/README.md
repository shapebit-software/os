# shapebit-installer-backend

Privileged installer backend. The first implementation should begin with:

1. `probe-disks`
2. `plan --dry-run`
3. `validate-plan`
4. transaction-log persistence
5. operations restricted to test loop/QEMU disks

Never execute arbitrary commands supplied by the frontend.
