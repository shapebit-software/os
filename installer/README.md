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

The [installer decision map](DECISION-MAP.md) assigns every planned operation to
its authoritative parent-repository ADR and exposes unresolved production
gates.

The first integration target is a serializable `InstallationPlan`, a mock or
dry-run backend, and UI integration without modifying a real disk. The parent
repository's
[system design](https://github.com/shapebit-software/docs/wiki/system-design)
defines the delivery sequence, responsibilities, and safety boundaries.

Human accounts use `systemd-homed` with one LUKS2 home per user. The login
password and generated recovery key use a separate secret-enrollment channel;
they never appear in `InstallationPlan` or transaction logs.

The physical root uses a separate TPM2-unlocked LUKS2 volume with a device
recovery key. Zram is the default swap; unencrypted disk-backed swap is never a
valid installation plan.

For the initial device owner, the installer presents the device recovery key
and the owner's home recovery key as one logical Recovery Kit while preserving
their independent cryptographic and access boundaries. The canonical UX is
defined in [`ui/README.md`](ui/README.md#recovery-kit).
