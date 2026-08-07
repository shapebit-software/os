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
- [ ] Every persistent host path is declared `preserved` or `disposable`.
- [ ] Representative `preserved` state passes N -> N+1 -> rollback N.
- [ ] Every `disposable` path can be safely recreated.
- [ ] The update performs no incompatible automatic persistent-data migration.
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
- [ ] `boot-complete.target` remains gated until every mandatory health check
  and the two-minute observation period succeed.
- [ ] `systemd-bless-boot` marks a successful UKI good.
- [ ] The UKI starts with two attempts and exhaustion selects the previous good
  entry.
- [ ] Manual rollback works.
- [ ] Automatic rollback works.
- [ ] Shutdown before acceptance consumes an attempt; shutdown after blessing
  does not.
- [ ] Automatic rollback locally blocks the failed digest.
- [ ] No active hibernation image exists during update or rollback.

## Recovery

- [ ] Recovery sees both deployments.
- [ ] Recovery unlocks LUKS with a recovery code.
- [ ] A report can be exported.
- [ ] A known stable release can be restored.
- [ ] A system reset does not delete `/home`.
- [ ] `Erase device` deletes data as communicated.

## Rollout

- [ ] The build is not blocklisted.
- [ ] Rollout waves are defined.
- [ ] The quality dashboard works.
- [ ] A stop-rollout procedure exists.
- [ ] Automatic pause and manual resume are tested.
- [ ] `withdrawn` cancels an unbooted staged deployment.
- [ ] Cached `revoked` metadata prevents the next boot offline.
- [ ] Minimal telemetry can be disabled without affecting updates.
- [ ] A superseding build or remediation plan exists.
