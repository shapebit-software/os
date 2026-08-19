# ADR-0033: Simple Test Evidence

**Status:** Accepted

**Date:** 2026-08-12

## Context

ADR-0014 defines the QEMU target, physical-hardware labels, and release gates,
but those claims still need a concrete record and pass rule. The initial project
is maintained by one person and does not need a certification platform,
cryptographically signed test database, or a separate evidence object for each
assertion.

## Decision

### One simple report

Every QEMU or physical-hardware run produces one human-readable YAML report.
It contains:

- ShapeBit version and exact image digest;
- date;
- environment type, `qemu` or `physical`;
- for QEMU, the named standard VM profile;
- for physical hardware, exact model or SKU and firmware version;
- the fixed checklist with `pass`, `fail`, or `not-tested` for every group;
- a short note for each failure;
- references to automatically retained logs for failed automated tests; and
- a mechanically computed overall `pass` or `fail`.

The initial report uses no cryptographic report signatures, separate evidence
schema, or per-test version number. A QEMU report is an ordinary CI artifact. A
physical report is the source for the published capability entry. Repository
history and the publishing account identify provenance in the initial project.

An omitted checklist entry is treated as `not-tested`. An official suite passes
only when every mandatory group is `pass`; `fail` and `not-tested` both make its
overall result `fail`. Logs are required for an automated `fail` but are not
collected as separate evidence objects for every successful check.

Example:

```yaml
release: 0.1.0
digest: sha256:...
date: 2026-08-12
environment: qemu
tests:
  install: pass
  secure-boot: pass
  update: pass
  rollback: fail
  recovery: not-tested
result: fail
```

### Mandatory QEMU groups

The complete QEMU suite reports these eight groups:

1. installation to an empty disk;
2. boot with Secure Boot enabled;
3. automatic system-volume unlock through the software TPM2;
4. device recovery-key unlock after TPM2 unlock is made unavailable;
5. user creation, login, and activation of the encrypted home;
6. update staging, trial boot, and successful acceptance;
7. automatic rollback after a deliberately failed deployment; and
8. boot of the independent recovery environment.

Each group may contain multiple internal assertions, but it has one report
result. Any failed assertion fails its group. The standard QEMU profile uses
x86-64 KVM, OVMF, Secure Boot, a software TPM2, the defined virtual storage,
network, and display devices, and no undeclared host-specific substitutions.

### Mandatory physical-hardware groups

An official physical run reports these eight groups:

1. installation, Secure Boot, TPM2 unlock, and device recovery-key unlock;
2. login and encrypted-home activation;
3. update, trial boot, acceptance, and pre-acceptance rollback;
4. built-in display, graphics, brightness, and scaling;
5. keyboard, touchpad, and present input devices;
6. Wi-Fi, Ethernet, and Bluetooth where that hardware is present;
7. speakers, microphone, headphones, and camera where present; and
8. battery reporting, power profiles, lid handling, suspend, and resume.

The report also contains a simple capability table for optional or
model-dependent features such as HDR, VRR, fingerprint readers, and charge
limits. Absence of optional hardware is recorded as absent and does not fail the
suite. If ShapeBit claims support for a present optional capability on that
model, its check must be `pass`; otherwise the published matrix records the
limitation.

`Officially-tested` requires an overall passing physical report performed and
published by ShapeBit for the exact release, hardware configuration, and
firmware version. The report is not transferable to a different release or SKU.

### Community-tested minimum

A community submission uses the same report and fills every group with `pass`,
`fail`, or `not-tested`. It identifies the exact release digest, model or SKU,
and firmware.

`Community-tested` requires `pass` for:

- installation and ordinary boot;
- login;
- display output;
- keyboard and touchpad;
- at least one network connection;
- audio output; and
- suspend and resume.

Update, rollback, independent recovery, and optional capabilities may remain
`not-tested`. Every reported failure is published as a known limitation. A
blocking failure of installation, login, display, or resume prevents the
`Community-tested` label. ShapeBit reviews the report for completeness and
plausibility but does not claim to have reproduced its results.

Known failures remain separate from the three evidence labels defined in
ADR-0014; this decision does not create another hardware label.

## Consequences

- Reports are easy to read, generate in CI, and fill during manual laptop
  testing.
- The overall official pass cannot hide a skipped mandatory group.
- Broad groups avoid a large evidence framework, but provide less granular
  history than per-assertion records.
- Successful groups do not retain dedicated proof beyond the report and normal
  CI history.
- Community results are useful for everyday compatibility without being
  presented as official validation.

## Boundaries

This ADR owns the initial report shape, result vocabulary, mandatory QEMU and
physical groups, overall pass calculation, and minimum community submission.
ADR-0014 owns platform scope, label meaning, and release gates. ADR-0034 owns
release timing. A future need for independent auditors, multiple release
maintainers, or machine-verifiable certification may justify a more rigorous
evidence format.

## Related decisions

- [ADR-0009](ADR-0009-staged-rollout.md)
- [ADR-0014](ADR-0014-platform-and-hardware-validation.md)
- [ADR-0015](ADR-0015-microsoft-shim-and-trust-domains.md)
- [ADR-0026](ADR-0026-boot-health-contract.md)
- [ADR-0034](ADR-0034-release-cadence-and-candidate-aging.md)
- [ADR-0040](ADR-0040-forward-only-migrations-and-trial-bounded-rollback.md)
