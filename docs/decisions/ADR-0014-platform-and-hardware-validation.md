# ADR-0014: Platform Scope and Hardware Validation

**Status:** Accepted
**Date:** 2026-08-06
**Last updated:** 2026-08-15

## Context

ShapeBit OS needs a reproducible virtual target, a realistic path to physical
hardware, and hardware claims that do not imply untested generic-PC support.
Fedora validates the base distribution and many upstream components, but it
does not validate the ShapeBit boot chain, storage policy, recovery behavior,
updates, rollback, or exact hardware integration.

## Decision

### Supported platform scope

- The initial automated target is x86-64 QEMU with OVMF and a software TPM.
- The official developer host class is Linux x86-64 with KVM. Fedora is the
  canonical host and the required CI environment.
- Other Linux distributions may use the same workflow when they provide the
  required host capabilities and pass the host check.
- macOS, Windows, WSL, ARM64 hosts, and arbitrary hypervisors are outside the
  initial official developer-host scope.
- Physical validation uses existing market-available laptops with upstream
  Linux support. ShapeBit does not define one reference laptop and does not
  initially develop custom hardware.

### Hardware evidence labels

Every physical hardware result uses exactly one of these evidence labels:

- **Officially-tested** — the ShapeBit team completed the mandatory product
  test suite and published the evidence.
- **Community-tested** — a community member submitted sufficient hardware and
  test information, but the ShapeBit team did not complete the official suite.
- **Unknown** — there is no sufficient current positive evidence. This label
  does not mean incompatible.

Known failures are recorded separately and do not create a fourth evidence
label.

Evidence is scoped to a ShapeBit release, exact hardware configuration, and
firmware version. It does not transfer automatically to a later ShapeBit
release, a similarly named model, or a different SKU.

### Official test meaning

`Officially-tested` requires the mandatory integration suite, including:

- full-disk installation and ordinary boot;
- Microsoft Secure Boot through the ShapeBit shim;
- TPM2 unlock and device-recovery-key unlock;
- per-user home activation and recovery;
- rejection of modified boot artifacts;
- update, trial boot, acceptance, and pre-acceptance rollback;
- recovery after an interrupted operation;
- required laptop graphics, networking, audio, input, battery, suspend, resume,
  shutdown, and supported firmware behavior.

Results are published as a capability matrix. Optional hardware features may
carry explicit limitations, but a missing mandatory result is not a pass.
ADR-0033 defines the simple YAML record, mandatory QEMU and physical groups,
overall pass calculation, and minimum community submission.

### Release gates

- Developer and nightly releases may be published after the complete required
  QEMU suite passes, even when no physical model is `Officially-tested`.
- Stable releases and the public alpha require at least one
  `Officially-tested` laptop for that exact release.
- A critical emergency security release may be published with
  `hardware validation pending` after its mandatory QEMU and security tests
  pass. ADR-0034 requires physical validation within 72 hours, and the trial
  rollback baseline must remain available until acceptance.

### Long-term self-hosting

Using the ShapeBit developer channel as the team's primary daily development
host is a distant goal, not an initial release requirement. Fedora remains an
independent bootstrap, CI, and recovery path. ShapeBit must never become the
only environment capable of rebuilding ShapeBit.

Both hosts will eventually use the same pinned ShapeBit SDK container. Build
capability does not grant access to production signing keys.

## Rationale

This model obtains broad base-system value from Fedora without claiming that
Fedora tested the assembled ShapeBit product. Versioned evidence avoids stale
compatibility claims, while QEMU keeps early development independent of one
physical laptop.

## Positive consequences

- Hardware claims have an auditable meaning.
- Early development is not blocked by a specific laptop.
- The physical test matrix can grow without redefining a reference platform.
- Fedora remains a reliable bootstrap while later ShapeBit self-hosting enables
  continuous dogfooding.

## Negative consequences

- Stable promotion requires recurring destructive physical tests.
- Hardware evidence expires with each release unless it is renewed.
- Community results cannot carry the same assurance as official results.
- Supporting multiple Linux development hosts requires capability detection.

## Boundaries

This ADR owns platform scope, hardware evidence labels, and release-level
hardware gates. It does not define the Secure Boot chain, disk layout, or the
detailed test implementation.

## Re-evaluation criteria

- ShapeBit begins developing or shipping custom hardware.
- macOS, Windows, ARM64, or non-KVM development becomes a product requirement.
- The project makes a hardware-support promise stronger than published test
  evidence.

## Related decisions

- [ADR-0001](ADR-0001-fedora-bootc.md)
- [ADR-0015](ADR-0015-microsoft-shim-and-trust-domains.md)
- [ADR-0016](ADR-0016-initial-installation-and-storage-profile.md)
- [ADR-0033](ADR-0033-simple-test-evidence.md)
- [ADR-0034](ADR-0034-release-cadence-and-candidate-aging.md)
- [ADR-0040](ADR-0040-forward-only-migrations-and-trial-bounded-rollback.md)
