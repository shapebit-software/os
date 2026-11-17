# Updates

os-update, its timer, and who may run it: the package `shapebit-updates`.

`os-update.timer` runs `os-update`
([os-update](os-update)) soon after
boot and every 6 hours, except on metered connections; Settings' **Check
now** starts `os-update@now.service`, which a polkit rule lets the person at
the computer start. It downloads and stages a new build with
`bootc upgrade`, never restarts, and writes its state for the shell to
`/run/os-update/status.json`.
