# Release Identity

Every ShapeBit release is identified by a signed immutable release manifest.

The manifest binds the exact artifacts that belong to one release:

version;
architecture;
OCI image digest;
signed UKI digest;
composefs root digest;
minimum compatible updater and recovery versions.
release manifest
├── OCI image
├── composefs root
└── signed UKI

Channels and tags such as stable or testing are discovery pointers only. They do not identify a release.

The updater accepts a deployment only when all referenced digests match the downloaded and locally prepared artifacts.

The manifest is strict and signed. Unknown or malformed fields are rejected.

Mutable data such as rollout state, mirrors, withdrawal, and revocation is stored separately and refers to the immutable release by digest.

## Artifact Binding

The release binds the system image and boot artifact through the composefs root digest:

OCI image
    ↓
composefs root
    ↓
rootfs digest
    ↓
signed UKI

The UKI contains the expected rootfs digest.

During boot, initrd:

obtains the expected digest from the signed UKI;
selects exactly one matching local deployment;
requires active fs-verity verification;
unlocks and switches to that deployment.

A missing, malformed, or mismatched identity is a hard boot failure.

The release manifest binds the final UKI digest, OCI image digest, and rootfs digest together so independently valid artifacts from different releases cannot be mixed.