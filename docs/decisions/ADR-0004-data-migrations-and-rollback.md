# ADR-0004: Data Migrations Independent of Image Rollback

**Status:** Accepted
**Date:** 2026-08-04
**Last updated:** 2026-08-07

## Context

A bootc rollback restores the base system, but persistent `/var` and `/home` remain. A destructive data migration may prevent the previous deployment from starting.

## Decision

- do not automatically roll back all of `/var` or `/home`;
- every component has a data-schema version;
- migrations are idempotent and logged;
- data compatibility between N and N-1 is required throughout the rollback
  window;
- a deployment is marked healthy only after critical migrations succeed.

A trial deployment may make only changes that remain readable by both the new
deployment and the retained previous deployment. Ordinary deployment
acceptance does not itself close the rollback window.

An irreversible migration is a separate rollback barrier. It requires:

- explicit owner authorization before the barrier is crossed;
- a previously released bridge version that understands both the old and new
  formats;
- preflight validation, an idempotent and logged transaction, and post-migration
  verification;
- disabling normal boot of deployments that cannot safely read the migrated
  state.

The bridge release must be deployed and exercised before a later release may
offer the irreversible transition. ShapeBit never combines the introduction of
a new-only data format with its first production exposure.

This ADR owns persistent-data compatibility. It does not define boot-attempt
counting or deployment selection. Those mechanisms only consume migration
results as defined by ADR-0007.

## Consequences

This requires disciplined data APIs, support for two formats during a bridge
period, and additional tests. It protects user documents and makes the claimed
N/N-1 rollback window real rather than merely restoring older system files over
incompatible persistent data.

## Open questions

- How long a bridge release receives security fixes when its owner declines the
  later rollback barrier.
- What migration-specific recovery artifact is required before crossing a
  barrier; the general snapshot policy remains deferred.

## Related decisions

- [ADR-0002](ADR-0002-filesystem-ownership.md) defines persistent paths.
- [ADR-0007](ADR-0007-trial-boot-and-acceptance.md) defines deployment
  acceptance and rollback selection.
