# ShapeBit OS — project bundle v0.5

This bundle consolidates all existing ShapeBit OS architecture documentation and the first implementation repository scaffold.

## Selected direction

```text
Fedora bootc
+ OSTree backend
+ systemd-boot
+ BLS
+ LUKS2
+ Btrfs
+ console-only system in the first stage
+ custom Dioxus installer
+ custom desktop environment and compositor at a later stage
```

## Structure

```text
os/
├── README.md
├── PROJECT-STATUS.md
├── NEXT-STEPS.md
├── MANIFEST.json
├── docs/
│   ├── architecture documents
│   ├── decisions/       # ADRs
│   └── checklists/
└── starter/
    ├── Containerfile
    ├── Justfile
    ├── image/
    ├── installer/
    ├── scripts/
    └── tests/
```

## Getting started

1. Read `PROJECT-STATUS.md`.
2. Then read `docs/14-first-prototype.md`.
3. Continue with `starter/README.md`.
4. The first implementation goal is a bootc image that boots to a TTY in QEMU.
5. The Dioxus installer will first be connected to a mock backend and later to the real installation backend.

## Primary documents

- `docs/01-product-vision.md`
- `docs/02-system-architecture.md`
- `docs/03-image-and-build-model.md`
- `docs/04-filesystem-and-state.md`
- `docs/05-updates-and-recovery.md`
- `docs/11-installer-and-hardware.md`
- `docs/13-roadmap.md`
- `docs/14-first-prototype.md`

## Status

The documentation remains at the design stage. Decisions marked `Accepted` are binding, while decisions marked `Proposed` require implementation validation and testing.
