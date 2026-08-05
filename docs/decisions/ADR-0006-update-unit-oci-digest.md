# ADR-0006: OCI Digest as the Release Unit

**Status:** Proposed  
**Date:** 2026-08-04

## Context

An OCI tag is mutable and may point to another image. Reproduction, auditing, and rollback require an immutable identifier.

## Decision

Every ShapeBit OS release is identified by an OCI digest. The `developer`, `nightly`, `testing`, and `stable` tags serve only as promotion pointers.

## Consequences

- exact deployment reproduction;
- safe promotion of the same artifact;
- ability to block a specific digest;
- the UI still displays a friendly release number.
