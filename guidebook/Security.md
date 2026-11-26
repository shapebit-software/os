# Security

## Encryption

Everything on the disk is encrypted, except the files the computer starts
from. Your home is encrypted again, with your password, so other people of
the computer can't read your files.

At startup, the disk unlocks by itself, with the computer's security chip
(TPM). The chip unlocks it only if the computer starts ShapeBit as expected,
signed by ShapeBit.

## Recovery key

The installer shows a **recovery key** once. Write it down or photograph it,
and keep it away from the computer.

The computer asks for it at startup when it can't unlock the disk by itself,
for example after:

- turning off Secure Boot or changing its settings,
- replacing the motherboard or the security chip, or
- a fault of the security chip.

Type the recovery key where it asks for a passphrase. Without it, the data on
the disk can't be recovered.

## Reporting a problem

Report security problems privately, as the
[security policy](https://github.com/shapebit-software/os/security/policy)
says.
