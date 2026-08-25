# ShapeBit Desktop

ShapeBit Desktop is the custom Wayland desktop environment for ShapeBit OS. It
organizes work around persistent Workspaces rather than an application taskbar.

This repository currently contains an early nested Smithay compositor, a GTK 4
shell prototype, and experimental private Wayland protocols. The nested path
exercises a system bar, Overview, session-only Workspaces, ordinary application
windows, and shell restart. It is not yet persistent, boot-integrated,
hardware-validated, or suitable as a complete desktop session.

## Repository map

- `compositor/` owns compositor state, rendering, input, window policy, and the
  server side of private protocols.
- `shell/` owns the unprivileged GTK shell, its presentation model, application
  catalog, and private-protocol client.
- `protocol/` generates shared client and server bindings from the private
  Wayland XML.
- `tests/` contains nested end-to-end validation and controlled fixtures.

## Development

Create and enter the Fedora development environment, then run the checks:

```sh
DBX_CONTAINER_MANAGER=docker distrobox assemble create --file distrobox.ini
distrobox enter shapebit-desktop
cargo fmt --check
cargo clippy --workspace --all-targets --all-features --locked -- -D warnings
cargo test --workspace --all-features --locked
./tests/nested-smoke.sh
```

Architecture, accepted decisions, proposals, and verified prototype behavior
are maintained in the
[ShapeBit Desktop documentation](https://shapebit.software/docs/desktop/).
