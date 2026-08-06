# ADR-0008: Independent Recovery Environment

**Status:** Proposed  
**Date:** 2026-08-04

## Context

The previous deployment may be insufficient when a failure affects the bootloader, storage, encryption, or shared data.

## Decision

ShapeBit OS will provide a separate, minimal, independently versioned recovery image.

## Requirements

- independence from the main compositor;
- system-volume unlocking with the device recovery key;
- per-user home unlocking with that user's recovery key;
- storage diagnostics;
- deployment selection;
- reinstallation of a known image;
- data export;
- factory reset.

## Consequences

Higher maintenance and storage costs, but a significantly better ability to repair the device.
