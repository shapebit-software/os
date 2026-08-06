# ADR-0004: Data Migrations Independent of Image Rollback

**Status:** Proposed
**Date:** 2026-08-04

## Context

A bootc rollback restores the base system, but persistent `/var` and `/home` remain. A destructive data migration may prevent the previous deployment from starting.

## Decision

- do not automatically roll back all of `/var` or `/home`;
- every component has a data-schema version;
- migrations are idempotent and logged;
- destructive migrations require component-level backups;
- data compatibility between N and N-1 is preferred throughout the rollback window;
- a deployment is marked healthy only after critical migrations succeed.

This ADR owns persistent-data compatibility. It does not define boot-attempt
counting or deployment selection. Those mechanisms only consume migration
results as defined by ADR-0007.

## Consequences

This requires disciplined data APIs and additional tests, but protects user documents and limits implicit state rollback.

## Related decisions

- [ADR-0002](ADR-0002-filesystem-ownership.md) defines persistent paths.
- [ADR-0007](ADR-0007-trial-boot-and-acceptance.md) defines deployment
  acceptance and rollback selection.
