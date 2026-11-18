# License

## ShapeBit OS

ShapeBit OS is source-available. ShapeBit's own software is licensed under the
[PolyForm Shield License 1.0.0](https://polyformproject.org/licenses/shield/1.0.0).
Fedora, the Linux kernel, and the other software that ShapeBit includes keep
their own licenses.

**Settings > Licenses** shows the license of every component on your
computer, and of each extra, also before you download it.

## Sources

ShapeBit's own code is in its
[repositories on GitHub](https://github.com/shapebit-software). The source
code of everything else in a release is published next to it, for as long as
that release can be downloaded:

- **The system**: the version your computer runs is `IMAGE_VERSION` in
  `/etc/os-release`, and Settings > Licenses names its sources. Download them
  with:

  ```sh
  podman artifact pull ghcr.io/shapebit-software/os:<version>-sources
  podman artifact extract ghcr.io/shapebit-software/os:<version>-sources <directory>
  ```

- **The installer**: its sources are
  [`shapebit-installer-sources.tar`](https://download.shapebit.software/shapebit-installer-sources.tar),
  beside it.

## Software bill of materials

Each release since November 2026 has a software bill of materials (SBOM): every
component, with its version and license, in SPDX 2.3 (`sbom.spdx.json`);
those of November 2026 also in CycloneDX 1.6 (`sbom.cdx.json`):

```sh
podman artifact pull ghcr.io/shapebit-software/os:<version>-sbom
podman artifact extract ghcr.io/shapebit-software/os:<version>-sbom <directory>
```

## This guidebook

Unless stated otherwise, this guidebook is licensed under the [Creative Commons
Attribution-NonCommercial-NoDerivatives 4.0 International
license](https://creativecommons.org/licenses/by-nc-nd/4.0/) (CC BY-NC-ND 4.0).

## Brand identity

The ShapeBit logo and other original brand artwork are copyrighted and are not
licensed for reuse. The ShapeBit name and logo may also be protected under
applicable trademark law. No trademark rights are granted by the software or
documentation licenses.
