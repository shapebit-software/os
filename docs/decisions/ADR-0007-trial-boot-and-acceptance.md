# ADR-0007: Trial Boot and Explicit Deployment Acceptance

**Status:** Proposed  
**Date:** 2026-08-04

## Context

Preparing a deployment does not prove that the device will boot correctly and start the desktop.

## Decision

A new deployment has trial status after its first boot. It becomes accepted only after passing multi-level health checks and critical migrations.

The default limit is three failed boot attempts.

## Consequences

We need a health agent, persistent markers, boot counting, and bootloader integration.
