# License

## ShapeBit OS

ShapeBit OS is source-available. ShapeBit-authored operating system software is licensed under the [PolyForm Shield License
1.0.0](https://polyformproject.org/licenses/shield/1.0.0).

Fedora, the Linux kernel, and other third-party components remain governed by their own licenses.

## Installed materials

Settings > Licenses lists the component materials under `/usr/share/licenses/`
and displays their full text locally. RPM-owned notices elsewhere, such as in
Python package metadata, are linked from that directory rather than moved.
ShapeBit's own license is installed under `/usr/share/licenses/shapebit/`.

The license texts of the optional models are part of the system, so they are
there before a model is downloaded.

Fixed texts are kept in the repository; the image build adds the notices that
some Fedora packages lack, from their exact source RPMs. Rules, code and
maintenance instructions are in
[`licensing/`](https://github.com/shapebit-software/os/tree/main/licensing).
This collection does not replace corresponding-source publication below or
component-specific decisions about license compatibility and distribution.

## Sources

Each version's sources are published next to it, for as long as that version
can be downloaded. For new builds, collection includes the source RPM of every
installed package that has one. Collection does not depend on package license
labels, which may omit embedded components or use unfamiliar identifiers.

- **The system**, `ghcr.io/shapebit-software/os:<version>`: its sources are
  `ghcr.io/shapebit-software/os:<version>-sources`, an OCI artifact with one
  file per source RPM. The image's label `software.shapebit.sources` names
  it, and so does each release's notes. To download them:

  ```sh
  podman artifact pull ghcr.io/shapebit-software/os:<version>-sources
  podman artifact extract ghcr.io/shapebit-software/os:<version>-sources <directory>
  ```

  The version that a computer runs is `IMAGE_VERSION` in `/etc/os-release`,
  and Settings > Licenses names its sources.
- **The installer**, [`shapebit-installer.img.xz`](https://download.shapebit.software/shapebit-installer.img.xz):
  its sources are
  [`shapebit-installer-sources.tar`](https://download.shapebit.software/shapebit-installer-sources.tar),
  beside it.

ShapeBit's own code is in its [repositories on GitHub](https://github.com/shapebit-software).

## Software bill of materials

Each released version of the system has a software bill of materials (SBOM)
next to it: `ghcr.io/shapebit-software/os:<version>-sbom`. It lists every
component with its version and license in two formats with the same content:
`sbom.spdx.json` (SPDX 2.3) and `sbom.cdx.json` (CycloneDX 1.6). Releases from
before November 2026 have none. To download it:

```sh
podman artifact pull ghcr.io/shapebit-software/os:<version>-sbom
podman artifact extract ghcr.io/shapebit-software/os:<version>-sbom <directory>
```

It lists the RPMs and Python packages that the image has, found by
[syft](https://github.com/anchore/syft), and the code each RPM declares it
bundles; ShapeBit itself; and the models that the system downloads on request,
as optional components. Its RPMs are checked to be exactly the installed ones,
whose source RPMs are the published sources. `make sbom` writes it for a local
image.

## Documentation

Unless stated otherwise, the documentation in this wiki is licensed
under the [Creative Commons Attribution-NonCommercial-NoDerivatives 4.0
International license](https://creativecommons.org/licenses/by-nc-nd/4.0/) (CC BY-NC-ND 4.0).

## Brand Identity

The ShapeBit logo and other original brand artwork are copyrighted and are not licensed for reuse. The ShapeBit name and logo may also be protected under applicable trademark law. No trademark rights are granted by the software or documentation licenses.
