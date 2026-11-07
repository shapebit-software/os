# License

## ShapeBit OS

ShapeBit OS is source-available. ShapeBit-authored operating system software is licensed under the [PolyForm Shield License
1.0.0](https://polyformproject.org/licenses/shield/1.0.0).

Fedora, the Linux kernel, and other third-party components remain governed by their own licenses.

## Sources

Each version's sources are published next to it, for as long as that version
can be downloaded: the source RPM of every package in it under a copyleft
license, such as the GPL, the LGPL, or the MPL.

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

## Documentation

Unless stated otherwise, the documentation in this wiki is licensed
under the [Creative Commons Attribution-NonCommercial-NoDerivatives 4.0
International license](https://creativecommons.org/licenses/by-nc-nd/4.0/) (CC BY-NC-ND 4.0).

## Brand Identity

The ShapeBit logo and other original brand artwork are copyrighted and are not licensed for reuse. The ShapeBit name and logo may also be protected under applicable trademark law. No trademark rights are granted by the software or documentation licenses.
