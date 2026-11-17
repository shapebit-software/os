# Boot

How a computer starts ShapeBit with trust, and unlocks its disk: the package
`shapebit-boot`. The UKI itself is made by
[distribution/Containerfile.seal](../../distribution/Containerfile.seal).

## Chain of trust

```text
UEFI Secure Boot → Fedora's shim (signed by Microsoft) → systemd-boot, signed by ShapeBit
  → the UKI, signed by ShapeBit → the sealed system
```

- PCs keep their manufacturer's Secure Boot keys. Shim trusts ShapeBit's key
  only after a person enrolls it, once per computer, at the installer's first
  boot ([guide](../../guide/Install.md)). [esp-shim](esp-shim) places shim on
  the medium and the installed disk; updates don't replace it yet.
- The UKI bundles the kernel, initramfs, command line, and TPM policy in one
  signed file, and pins the system's composefs digest: if the system on disk
  doesn't match, the boot stops, with no fallback. No unsigned kernel is on
  the EFI System Partition, which holds no secrets.
- The command line is machine-independent, as a UKI can't carry per-machine
  arguments: the root is found by its GPT type ([20-root.toml](20-root.toml)).

## Unlocking the disk

The LUKS2 volume has two key slots:

| Slot | Unlocks |
| --- | --- |
| TPM2 | Every normal boot, without a prompt |
| Recovery key | When the TPM refuses; shown once by the installer, asked for by the splash |

The TPM slot is bound to **PCR 7** (the Secure Boot policy, a fixed value)
and to **PCR 11** values signed by the PCR key, so a new UKI signed with the
same key unlocks without re-enrollment. PCR 0, 2, and 14 aren't checked. The
TPM must never be the only way in: one hardware fault would lock the owner out
for good.

## Planned

- ShapeBit's own shim, signed by Microsoft, so PCs boot without enrolling a
  key; computers move to it by an update, with their TPM enrollment.
- A minimal signed recovery UKI, using the `@recovery` subvolume.
