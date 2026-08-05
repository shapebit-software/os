# Checklist: ShapeBit OS update candidate

## Artifact

- [ ] The image has an immutable digest.
- [ ] The digest passed tests without being rebuilt.
- [ ] The release manifest is signed.
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

- [ ] The pending deployment boots.
- [ ] L0–L4 health checks work.
- [ ] The acceptance marker is persisted.
- [ ] Manual rollback works.
- [ ] Automatic rollback works.
- [ ] Boot counting does not treat a normal shutdown as a failure.

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
