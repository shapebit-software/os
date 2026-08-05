# 12. CI/CD and Testing

**Status:** Draft

## Pipeline

```text
commit
→ lint
→ unit tests
→ build RPM
→ build image
→ bootc lint
→ security scan
→ boot QEMU
→ service tests
→ desktop tests
→ update test
→ rollback test
→ sign
→ publish
```

## Test types

- unit tests;
- integration tests;
- boot tests;
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
- signature.

## Publishing rule

The stable image must have the same digest that passed testing. It must not be rebuilt after acceptance.
