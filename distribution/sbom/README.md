# SBOM

The software bill of materials published with each build ([sbom.py](sbom.py)):
what it contains, for license reviews and for security scanners, which match
its packages against known vulnerabilities. [release.py](../release.py)
publishes it as the OCI artifact `<version>-sbom`.

The SBOM, in SPDX 2.3, lists the RPMs and Python packages that syft finds,
the code each RPM declares it bundles (`Provides: bundled(...)`), ShapeBit
itself, and the downloadable models as optional components; its RPMs are
checked to be exactly the installed ones. `distribution/release.py sbom IMAGE DIR`
writes it for a local image.
