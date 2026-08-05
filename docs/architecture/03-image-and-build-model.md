# 03. Image and Build Model

**Status:** Draft

## System artifact

The release unit is a signed, bootc-compatible OCI image.

```text
Fedora bootc base
+ Fedora packages
+ ShapeBit OS packages
+ configuration
+ SELinux policies
= ShapeBit OS image
```

## Build rules

- builds must be automated;
- inputs must be versioned;
- every image receives an immutable digest;
- channel tags point to specific digests;
- stable is never built manually on a developer workstation;
- custom binaries should be delivered to production as RPMs.

## Proposed structure

```text
os-image/
├── Containerfile
├── manifests/
├── overlays/
│   ├── usr/
│   └── etc/
├── selinux/
├── scripts/
└── tests/
```

## OCI layers

OCI layers are a composition and transport mechanism, not a user interface. Users should not manage individual layers.

## Package layering

The primary supported form is build-time layering:

```Dockerfile
FROM <fedora-bootc-base>
RUN dnf install -y shapebit-compositor shapebit-shell
```

Client-side package layering is not part of the core product model.

## Reproducibility

Every build should record:

- the source Git commit;
- the base-image version;
- the list of RPMs and their versions;
- the image digest;
- test results;
- the release signature;
- the SBOM.
