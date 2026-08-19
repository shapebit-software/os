# ADR-0032: Host Customization and Integrity Status

**Status:** Accepted

**Date:** 2026-08-12

## Context

Bootc updates the image-owned system while preserving host-specific `/etc` and
`/var` state. ShapeBit therefore needs to distinguish supported configuration,
ordinary administrator customization, and actual loss of trust in protected
boot or image artifacts. Treating every writable-host change as an integrity
failure would make normal administration unusable; treating every root change
as supported would make diagnostics and recovery misleading.

The initial mechanism must remain diagnostic and simple. It is not intended to
defend its own records from an already-authorized malicious root process.

## Decision

### Configuration layers

ShapeBit components use these ownership and precedence layers:

```text
built-in program defaults
< /usr/lib/shapebit/<component>   image-owned vendor configuration
< /run/shapebit/<component>       temporary runtime overrides
< /etc/shapebit/<component>       persistent local overrides
```

`/var/lib/shapebit/<component>` stores mutable service state, not administrator
configuration. A lower line in the diagram has higher precedence. Local files
store the smallest practical override rather than a full copy of vendor
configuration.

ShapeBit follows equivalent upstream `/usr/lib`, `/run`, and `/etc` precedence
where a component already defines it. Software that cannot separate vendor
defaults from local configuration requires an explicit migration plan with a
rollback-compatible `prepare` phase; ShapeBit does not assume that bootc will
semantically merge its configuration.

### Status model

The device exposes three current statuses:

- **Managed**: controlled writable configuration matches the state created by
  ShapeBit or a supported API, and protected artifacts pass integrity checks;
- **Customized**: a controlled writable host area contains a local change not
  represented by the supported configuration state; and
- **Integrity failure**: a signed, measured, or otherwise protected image,
  boot, mandatory SELinux, or trust-domain artifact fails its authoritative
  verification.

Flatpaks, AppImages, Distrobox containers, ordinary user files, and enabling
developer mode do not make the host `Customized`. A supported trust change made
through `software.shapebit.trust` is managed state, not an integrity failure.

`Customized` is recomputed and reversible. Returning every controlled path to
its expected state returns the device to `Managed`; it is not a permanent
record that customization once occurred.

### Simple customization detection

A root-owned manifest in protected system state records the current expected
configuration produced through ShapeBit and supported upstream APIs. For each
managed file it records only the path, content digest, owner, mode, and expected
file type. Manifest replacement is atomic. It does not duplicate file contents
or serve as integrity authority for the image or boot chain.

The scanner is intentionally allowlisted rather than a hash of all `/etc`. Its
initial controlled scope covers:

- `/etc/shapebit`;
- systemd system units and drop-ins under `/etc/systemd/system`;
- local Polkit policy and rules;
- udev, kernel-module, and sysctl overrides;
- SSH server configuration;
- SELinux local policy and configuration;
- boot and local trust configuration; and
- NetworkManager system-connection configuration tracked after supported API
  operations.

A changed expected file, unexpected entry, wrong type, owner, or mode in this
scope produces `Customized` unless an authoritative protected-artifact check
classifies it as an integrity failure. Areas outside the allowlist are not
claimed to be assessed in the initial product.

The scan runs during boot diagnostics, before update staging, after a supported
administrator operation, and on explicit diagnostic request. Its report lists
differences without copying secret file contents. This mechanism detects
ordinary drift; root can alter both configuration and the manifest, so it is
not a security boundary.

### Behavior of a customized system

A `Customized` system continues to boot and update. Secure Boot, trial boot,
rollback, recovery, and other protections remain active. Settings and
Diagnostics show the changed paths and associate a change with the affected
support area where possible.

Support is limited only for behavior plausibly affected by the customization;
an unrelated subsystem does not lose its support status. Reports record the
relevant differences. ShapeBit never overwrites or deletes a customization
merely because it was detected.

Update staging is blocked only when a concrete difference prevents safe
staging or violates a declared compatibility requirement of the new release.
The diagnostic result must name the blocking requirement and affected path.

### Integrity-failure behavior

Protected image and boot artifacts use their signed manifests, measurements,
and trust policy rather than the customization manifest. An integrity failure
during a trial boot is a deterministic hard failure under ADR-0026. Before
normal startup, ShapeBit selects the previous trusted deployment or independent
recovery when none exists. The failed deployment is locally blocked from
automatic selection and produces a critical diagnostic report.

If an integrity failure is detected in an already running accepted deployment,
ShapeBit blocks new privileged mutations and update staging, writes the minimal
critical report, selects the previous trusted deployment, and performs a
controlled restart after a brief critical warning. Preserving unsaved work does
not override loss of trust. If no trusted deployment exists, the restart enters
independent recovery.

There is no **Ignore** or **Mark trusted** action for a failed artifact. Only an
explicitly authorized trust-domain operation or installation of a correctly
verified deployment can establish trust.

### Restoring managed configuration

An active local administrator may restore one detected customization or all of
them. Before authorization, ShapeBit shows the exact files that it will remove,
replace, or recreate. The operation reconstructs the current image defaults and
supported settings without using a filesystem snapshot.

Before changing a file, ShapeBit copies the original into a root-only encrypted
quarantine in `@state`. Quarantined files are data and are never executed. The
replacement is atomic, and failure restores the pre-operation state. The same
operation is available from independent recovery when customization prevents
normal startup.

Quarantine entries expire after 30 days and have a combined limit of 256 MiB.
An administrator may undo a restoration while its complete entry remains. If a
new restoration would exceed the limit, ShapeBit stops before making changes
and offers manual export; it does not evict an existing entry silently to admit
the new operation.

## Consequences

- Vendor defaults update atomically with `/usr`, while local overrides survive
  bootc deployment changes.
- A bounded allowlist is understandable and testable, but does not claim to
  detect every possible `/etc` customization.
- Advanced administration remains possible without disabling unrelated support
  or system updates.
- The customization manifest improves diagnostics but cannot attest against a
  hostile root process.
- Restoration is reversible without adding the managed snapshot mechanism that
  ADR-0029 rejects.
- Confirmed loss of protected-artifact trust prioritizes a trusted restart over
  an active session's unsaved work.

## Boundaries

This ADR owns ShapeBit configuration layering, host-status classification,
allowlisted customization detection, support effects, integrity-failure
response, and configuration restoration quarantine. ADR-0002 owns general
filesystem ownership. ADR-0013 owns boot trust and authorized trust-domain
changes. ADR-0026 owns trial-boot hard-failure transitions. ADR-0029 owns the
absence of managed snapshots. ADR-0031 owns diagnostic report data handling.

## Related decisions

- [ADR-0002](ADR-0002-filesystem-ownership.md)
- [ADR-0040](ADR-0040-forward-only-migrations-and-trial-bounded-rollback.md)
- [ADR-0008](ADR-0008-independent-recovery.md)
- [ADR-0013](ADR-0013-boot-trust-and-tpm-policy.md)
- [ADR-0018](ADR-0018-desktop-session-and-authorization.md)
- [ADR-0026](ADR-0026-boot-health-contract.md)
- [ADR-0029](ADR-0029-no-managed-snapshots.md)
- [ADR-0031](ADR-0031-diagnostic-reports-and-consent.md)

## References

- [How bootable container images work](https://containers.github.io/bootable/how-does-it-work.html)
- [Filesystem Hierarchy Standard: `/etc`](https://specifications.freedesktop.org/fhs/latest/etc.html)
- [systemd configuration precedence](https://www.freedesktop.org/software/systemd/man/251/homed.conf.html)
