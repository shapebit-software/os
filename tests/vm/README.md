# Machines

`make disk` ([vm/disk.sh](disk.sh)) installs the way a person does: it
boots the medium in QEMU with an empty disk of `DISK_SIZE`, checks the medium
([medium/](../checks/medium/)), and installs through `installerctl`, the command-line
client of the installer's D-Bus interface. It never builds a disk any other
way. `make installer-vm` opens the same VM in a window.

The VM's EFI variables (`build/efivars.qcow2`) and TPM state (`build/tpm/`)
belong to the machine, which the medium and the disk share; `make disk`
resets them. [vm/mok-enroll.sh](mok-enroll.sh) accepts the MOK on the VM,
whose firmware starts with Microsoft's keys.

**Development access.** Images and disks contain no credentials. `make disk`,
`make vm`, and `make test` generate an SSH key in `build/ssh/` and pass it as
the systemd credential `ssh.authorized_keys.root`. `make disk` gives the
installer the first owner, `OWNER_NAME`, with the password in
`build/owner-password`, and `LOCALE`, `KEYBOARD_LAYOUT`, and `TIME_ZONE`; the
recovery key goes to `build/recovery-key`. There is no root password.

**Updates from a local build.** `make publish` pushes the image
([update/publish.sh](../checks/update/publish.sh)) to a registry container on the
host ([update/registry.sh](../checks/update/registry.sh)). The VM marks it
insecure, as it serves plain HTTP, and switches to it through `10.0.2.2`:

```bash
printf '[[registry]]\nlocation = "10.0.2.2:5000"\ninsecure = true\n' \
  >/etc/containers/registries.conf.d/50-dev-registry.conf
bootc switch 10.0.2.2:5000/shapebit-os:dev
```

**Real hardware.** A medium built locally is signed with the development
keys; later updates from `stable` would need the release keys enrolled too.
Write `build/installer.img` to a USB drive of at least 8 GB with `dd`, and
install as the [guidebook](../../guidebook/Install.md) says. To run the system checks
on it, log in on a console (Ctrl+Alt+F3), connect to the network, allow root
to log in with `build/ssh/id_ed25519.pub`, and run
`make test-guest GUEST=ADDRESS IMAGE_DIGEST=sha256:... OWNER_NAME=... LOCALE=... KEYBOARD_LAYOUT=... TIME_ZONE=...`.
On the medium, `journalctl -b -u installer-backend.service` shows the
installation.

