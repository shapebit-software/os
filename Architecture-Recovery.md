# Recovery

Every device has a **recovery key** — a backup way to unlock the encrypted
disk if the normal, automatic unlock ever fails.

## When the recovery key is needed

The disk normally unlocks itself using the TPM chip, with no password
needed. The TPM refuses to unlock the disk if the boot environment looks
different than expected. This can happen when:

- the TPM chip fails
- Secure Boot settings change
- the motherboard is replaced
- the boot measurements (PCRs) no longer match what's expected

In any of these cases, the recovery key unlocks the disk instead.

## Why this matters

The TPM is convenient, but it must never be the *only* way in. If it were,
a single hardware fault could lock the owner out of their own data for
good. The recovery key guarantees there's always a way back in, independent
of the TPM.