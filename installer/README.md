# ShapeBit installer

This repository will contain the custom ShapeBit OS installer. The frontend,
shared protocol, and privileged backend are deliberately separated:

```text
ui -> protocol -> backend
```

- [`ui/`](ui/README.md) contains the Dioxus frontend.
- [`protocol/`](protocol/README.md) contains shared requests, plans, events, and
  errors.
- [`backend/`](backend/README.md) performs validated privileged operations.

The first integration target is a serializable `InstallationPlan`, a mock or
dry-run backend, and UI integration without modifying a real disk. The
[first-prototype plan](https://github.com/shapebit-software/os/blob/main/docs/architecture/14-first-prototype.md)
defines the delivery sequence; the
[installer architecture](https://github.com/shapebit-software/os/blob/main/docs/architecture/11-installer-and-hardware.md)
defines responsibilities and safety boundaries.
