# ADR-0002: Filesystem Ownership Boundaries

**Status:** Proposed  
**Date:** 2026-08-04

## Context

An image-based system requires a clear separation between code, machine configuration, and persistent state. Without it, image rollback may conflict with local changes.

## Decision

- `/usr` and `/opt` belong to the image and are read-only during normal operation.
- `/etc` stores only device and administrator configuration.
- `/var` stores persistent service state.
- `/home` stores user data and preferences.
- `/run` and `/tmp` are ephemeral.
- vendor defaults should be placed in `/usr`, not `/etc`, when supported by the component.

## Positive consequences

- predictable deployments;
- auditable changes;
- simpler image rollback;
- less configuration drift.

## Negative consequences

- some existing software will require changes;
- `/etc` and `/var` migrations must be designed;
- administrators cannot treat the host like a traditional Fedora installation.

## Review criteria

Review after the first working update + rollback in M2.
