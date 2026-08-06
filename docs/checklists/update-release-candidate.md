# Checklist: ShapeBit OS update candidate

## Artifact

- [ ] The image has an immutable digest.
- [ ] The digest passed tests without being rebuilt.
- [ ] The release manifest is signed.
- [ ] The signed `security_epoch` is present and does not decrease.
- [ ] The image/attestation is signed.
- [ ] The SBOM is available.
- [ ] Release notes are ready.

## Compatibility

- [ ] Updating from the previous stable release works.
- [ ] Updating from the oldest supported stable release works.
- [ ] Critical data schemas support N-1 rollback.
- [ ] `/etc` conflicts have been tested.
- [ ] The minimum required free space has been checked.

## Boot and rollback

- [ ] systemd-boot and every promoted UKI have valid Secure Boot signatures.
- [ ] Every UKI contains the expected signed PCR 11 policy.
- [ ] Sealed deployment digest and required fs-verity verification pass.
- [ ] TPM2 unlock authorizes the pending and retained rollback UKIs.
- [ ] A modified UKI and mismatched deployment are rejected.
- [ ] The device recovery key still unlocks the system volume.
- [ ] The pending deployment boots.
- [ ] L0–L4 health checks work.
- [ ] The acceptance marker is persisted.
- [ ] Manual rollback works.
- [ ] Automatic rollback works.
- [ ] Boot counting does not treat a normal shutdown as a failure.
- [ ] No active hibernation image exists during update or rollback.

## Recovery

- [ ] Recovery sees both deployments.
- [ ] Recovery unlocks LUKS with a recovery code.
- [ ] A report can be exported.
- [ ] A known stable release can be restored.
- [ ] A system reset does not delete `/home`.
- [ ] A full reset deletes data as communicated.

## Rollout

- [ ] The build is not blocklisted.
- [ ] Rollout waves are defined.
- [ ] The quality dashboard works.
- [ ] A stop-rollout procedure exists.
- [ ] A superseding build or remediation plan exists.
