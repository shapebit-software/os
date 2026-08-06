# 12. CI/CD and Testing

**Status:** Proposed

**Last updated:** 2026-08-05

**Related ADRs:** ADR-0013

## Pipeline

```text
commit
→ lint
→ unit tests
→ build RPM
→ build image
→ bootc lint
→ security scan
→ controlled signing
→ boot QEMU
→ Secure Boot and TPM2 policy tests
→ service tests
→ desktop tests
→ update test
→ rollback test
→ publish
```

## Test types

- unit tests;
- integration tests;
- boot tests;
- Secure Boot signature and rejection tests;
- TPM2 unlock, policy-mismatch, and recovery-key tests;
- systemd service tests;
- SELinux tests;
- update tests;
- rollback tests;
- `/etc` and `/var` migration tests;
- compositor graphics tests;
- hardware tests;
- recovery tests.

## Build artifacts

- RPMs;
- debug images;
- bootc image;
- VM disk image;
- SBOM;
- package manifest;
- test report;
- release notes;
- release-manifest signature;
- signed UKIs and PCR policy signatures.

## Publishing rule

The stable image must have the same digest and signed boot artifacts that passed
testing. It must not be rebuilt or re-signed after acceptance. Production
signing uses a restricted service; general CI and pull-request jobs have access
only to disposable development keys.
