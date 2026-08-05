# Next steps

## Stage 1 — run the starter

- [ ] Select Fedora as the development host.
- [ ] Install Podman, Just, QEMU/KVM, and OVMF.
- [ ] Build `starter/Containerfile`.
- [ ] Run `bootc container lint`.
- [ ] Create a disk image.
- [ ] Run it in QEMU.

## Stage 2 — final disk layout

- [ ] Define the exact GPT layout.
- [ ] Create the ESP.
- [ ] Create the LUKS2 container.
- [ ] Create Btrfs and its subvolumes.
- [ ] Install systemd-boot.
- [ ] Confirm the BLS entries.
- [ ] Boot the system to a TTY.

## Stage 3 — updates

- [ ] Build image A.
- [ ] Build image B.
- [ ] Publish them to a local registry.
- [ ] Perform a bootc update.
- [ ] Test rebooting.
- [ ] Test manual rollback.
- [ ] Then implement trial boot and acceptance.

## Stage 4 — Dioxus installer

- [ ] Move the existing project to `starter/installer/ui`.
- [ ] Create a Rust workspace.
- [ ] Create the `installer-protocol` crate.
- [ ] Define `InstallationPlan`.
- [ ] Add validation and serialization.
- [ ] Create a mock backend.
- [ ] Connect the UI to the mock backend.
- [ ] Only then add real storage operations.

## Definition of the first success

The first success is not yet a graphical installer or desktop environment. It is:

```text
git clone
→ just build
→ just disk
→ just run
→ log in on the TTY
```
