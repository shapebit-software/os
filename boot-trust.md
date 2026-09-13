# Boot Trust

The system boots through:

UEFI Secure Boot
    ↓
Microsoft-signed ShapeBit shim
    ↓
signed systemd-boot
    ↓
signed ShapeBit UKI
    ↓
verified system deployment

The UKI contains the kernel, initramfs, kernel command line, and TPM PCR policy. The system does not maintain separate unsigned kernel or initramfs files on the ESP.

The ESP is unencrypted and contains no private keys or user data.

Production systems retain the manufacturer's normal UEFI PK/KEK configuration. Custom firmware-key enrollment is not required.

## Development

OVMF
→ ShapeBit Dev CA
→ dev-signed UKI