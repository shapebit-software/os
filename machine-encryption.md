# Machine Encryption

The machine volume uses LUKS2.

Normal boot unlocks it automatically through TPM2. Every device also has an independent recovery key.

TPM authorization uses:

PCR 7 for Secure Boot policy;
signed PCR 11 policy for approved ShapeBit UKIs.

PCR 11 uses signed expected measurements rather than one fixed value, allowing approved OS updates without TPM re-enrollment after every release.

PCR 0, 2, and 14 are not part of the default policy.

ShapeBit v1 uses TPM-policy functionality supported by the selected systemd release. It does not introduce a custom TPM policy engine unless required by a future architecture revision.
