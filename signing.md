Signing

Production and development builds use separate trust domains.

ShapeBit v1 uses a small production hierarchy:

offline root
├── release signing
├── boot + PCR signing
└── repository signing

The root key delegates operational keys and is not used for ordinary release signing.

Production private keys must:

remain outside Git and OCI images;
never be installed on user systems;
never be exposed to ordinary CI jobs;
use hardware-backed or equivalently protected storage.

Development uses clearly distinct disposable keys.

More granular role separation and threshold root signing may be introduced as the project and release organization grow.

Signing Process

CI produces unsigned release artifacts and their digests.

Production signing requires explicit authorization.

The release is signed only after the final OCI image, rootfs identity, UKI, and metadata are fixed.

Signing operations produce an immutable audit record identifying the inputs and outputs.