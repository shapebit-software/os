# User Guide

- [Installing](Install.md): write the installer to a USB drive and install.
- [Shortcuts](Shortcuts.md): the keyboard shortcuts of the desktop.

## Developing on ShapeBit

The immutable host ships with rootless Podman and Distrobox, so you can develop and install tools without touching the base system.

### Containers, not sandboxes

Distrobox exists for convenience and compatibility. It is **not** a security sandbox.

### Default container image

New containers start from the Fedora image matching the Fedora major version of your OS base.

### What's next

A dedicated ShapeBit OS development image is planned for a future release.
