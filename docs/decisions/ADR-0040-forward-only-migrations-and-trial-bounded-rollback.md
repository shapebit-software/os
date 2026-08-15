# ADR-0040: Forward-Only Migrations and Trial-Bounded Rollback

**Status:** Accepted
**Date:** 2026-08-15

## Context

ADR-0004 avoided incompatible automatic migrations so that a previously
accepted deployment could remain usable indefinitely with shared persistent
state. That contract makes every host format an N/N-1 compatibility promise,
requires compatible backports, and prevents old representations from being
removed while the previous deployment remains a supported rollback target.

ShapeBit needs a simpler initial rule: an update must be safely reversible while
its new deployment is being tested, but it does not need to promise a manual
rollback after that deployment has been accepted.

## Options considered

1. Keep every preserved host format compatible with N and N-1 indefinitely.
2. Snapshot all persistent system state and restore it with an old deployment.
3. Use forward-only migrations with a rollback boundary at trial acceptance.
4. Keep separate long-lived state generations for every host service.

## Decision

ShapeBit uses forward-only host-state migrations and guarantees deployment
rollback only until the new deployment is durably accepted.

The target bootc image carries the complete ordered migration history needed by
that image. A device jumping across several releases runs every missing
migration in order, using a durable migration ledger. The release manifest does
not need a source-release or direct-update-from field merely to enumerate an
update path.

Each incompatible migration has two phases:

1. `prepare` runs before or during the trial and may only make additive,
   idempotent, power-loss-safe changes that the old accepted deployment can
   safely ignore. The old representation remains authoritative and usable.
2. after health checks and the observation period succeed, durable deployment
   acceptance closes the rollback guarantee; `commit` may then make the new
   representation authoritative and remove data required only by the old
   deployment.

The new deployment must be able to resume an interrupted `prepare` or `commit`
and operate safely while a commit is pending. Acceptance must be durable before
any incompatible commit begins. After acceptance and before commit, ShapeBit
retires the old baseline from normal and recovery boot selection. A failure
before acceptance selects the old accepted deployment. A failure after
acceptance is repaired by resuming the forward migration, recovery, or a newer
fixed release; it does not reactivate a guaranteed old-system rollback.

Migrations are forward-only. ShapeBit does not require general reverse
migrations. A previous OCI image may remain physically cached after acceptance,
but it is not exposed as a bootable rollback target and may be removed by normal
cleanup. Strong cryptographic prevention of reintroducing an older signed boot
artifact belongs to the TPM2 anti-rollback decision.

This contract covers ShapeBit-owned persistent host state, including managed
system configuration. It does not migrate human home contents or application
data owned by Flatpak or AppImage applications. A migration that changes human
data requires a separate accepted decision.

ShapeBit does not create a whole-`@state` snapshot for an update. ADR-0029's
no-managed-snapshot policy remains in force.

This ADR supersedes ADR-0004. It also limits the rollback operation described by
ADR-0005 to the pre-acceptance guarantee and defines the persistent-state side
of the acceptance boundary owned operationally by ADR-0007.

## Boundaries

This ADR owns migration ordering, the prepare/commit boundary, and the duration
of the persistent-state rollback guarantee. ADR-0007 owns trial attempt
counting, health acceptance, boot selection, and blessing. The concrete
migration package format and runner protocol remain implementation design.

## Rationale

The model follows the useful boundary of Android-style A/B updating: the system
update can return to its known-good baseline while the candidate is unaccepted,
but shared durable data is not treated as an indefinitely reversible snapshot.
It permits direct jumps through a tested migration chain without requiring
down-migrations or long-lived duplication of all system state.

## Positive consequences

- Trial failure has a clear and testable rollback guarantee.
- Accepted releases may eventually remove obsolete host-state formats.
- Direct release jumps use the migration history in the target image.
- ShapeBit needs neither general reverse migrations nor update-wide snapshots.

## Negative consequences

- A problem discovered after acceptance cannot be solved by promising a safe
  boot of the previous deployment.
- Prepare phases must remain compatible with the old deployment.
- Commit and its ledger must be resumable after power loss.
- Recovery and fix-forward paths become important for post-acceptance failures.

## Risks

- Accepting a deployment before its prepare work is complete could strand the
  device between formats.
- Starting commit before the old boot entry is retired could expose an
  incompatible deployment as an apparently usable boot choice.
- A destructive action accidentally placed in `prepare` could break automatic
  rollback.
- A defective commit could require recovery even though the trial boot passed.

Release validation must therefore exercise direct jumps, interruption at every
durable migration checkpoint, pre-acceptance rollback, and post-acceptance
commit resumption.

## Re-evaluation criteria

- Users require a guaranteed manual rollback days after acceptance.
- A required migration cannot be split into a backward-compatible prepare and
  a resumable forward commit.
- Concrete state size or write amplification justifies scoped generations or
  migration-specific backups.

## Related decisions

- [ADR-0004](ADR-0004-data-migrations-and-rollback.md) is superseded by this
  ADR.
- [ADR-0005](ADR-0005-recovery-operation-semantics.md) separates rollback from
  repair, backup, and reset.
- [ADR-0007](ADR-0007-trial-boot-and-acceptance.md) defines trial boot and
  durable acceptance.
- [ADR-0029](ADR-0029-no-managed-snapshots.md) rejects managed filesystem
  snapshots.
