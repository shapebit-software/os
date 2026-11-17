# Updates

os-update, its timer, and who may run it: the package `shapebit-updates`.

`os-update.timer` runs `os-update`
([os-update](os-update)) soon after
boot and every 6 hours, except on metered connections; Settings' **Check
now** starts `os-update@now.service`, which a polkit rule lets the person at
the computer start. It downloads and stages a new build with
`bootc upgrade`, never restarts, and writes its state for the shell to
`/run/os-update/status.json`.

Rules: an update never restarts the computer or ends a session; it is
installed at the next restart or shutdown, and the previous release stays
installed (`bootc rollback`). The TPM unlocks the new release without
re-enrollment ([packages/boot](../boot/README.md)).

## Planned: trial boot

A new release boots on trial, with two attempts, through systemd's Automatic
Boot Assessment, and is accepted once a health check passes and keeps passing
for a short time: it is the expected release, system storage is present,
critical services and the network stack run, and the login screen is usable;
no internet or login needed. A clear integrity failure rolls back at once;
otherwise the computer starts the previous release once the attempts run out.
A failed release isn't staged again until a newer one replaces it.

Blocked upstream: bootc's composefs backend doesn't add boot counters to its
entries yet (planned through `/etc/kernel/tries`), and Fedora 45's SELinux
policy doesn't let `systemd-bless-boot` (`init_t`) rename files on the ESP
(`dosfs_t`).
