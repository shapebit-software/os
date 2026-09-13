# Development

The immutable host ships with rootless Podman and Distrobox, so you can develop and install tools without touching the base system.

## Containers, not sandboxes

Distrobox exists for convenience and compatibility. It is **not** a security sandbox.

## Default container image

New containers start from the Fedora Toolbox image matching the Fedora major version of your OS base.

## What's next

A dedicated ShapeBit OS development image is planned for a future release.