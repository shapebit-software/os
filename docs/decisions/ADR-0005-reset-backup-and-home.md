# ADR-0005: Separate Rollback, Backup, and Factory Reset

**Status:** Proposed  
**Date:** 2026-08-04

## Context

System rollback, data restoration, and device reset solve three different problems. Combining them creates a risk of data loss.

## Decision

- rollback changes only the system deployment;
- backup protects user data and selected settings;
- system reset restores the system and host configuration while preserving `/home`;
- full factory reset also removes user accounts and data;
- a filesystem snapshot is not considered the sole backup.

## Consequences

The recovery interface must clearly present the three separate operations and their effects.
