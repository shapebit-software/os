# License

## ShapeBit OS

ShapeBit OS is free and open-source software. ShapeBit's own files are under
open licenses, chosen by what each file is:

- **Programs**, such as the desktop, the system, and updates: the
  [GNU General Public License, version 3](https://www.gnu.org/licenses/gpl-3.0.html)
  or any later version (GPL-3.0-or-later).
- **Code that other programs can build on**, such as ShapeBit's colors: the
  [GNU Lesser General Public License, version 3](https://www.gnu.org/licenses/lgpl-3.0.html)
  or any later version (LGPL-3.0-or-later).
- **Configuration and examples** you may want to copy, such as the window
  manager's settings and the assistant's built-in skills: the
  [MIT License](https://spdx.org/licenses/MIT.html).
- **Documentation and artwork**, such as this guidebook: the
  [Creative Commons Attribution-ShareAlike 4.0 International license](https://creativecommons.org/licenses/by-sa/4.0/)
  (CC BY-SA 4.0).

The [source repository](https://github.com/shapebit-software/os) lists the
license of every file in `REUSE.toml`. Fedora, the Linux kernel, and the other
software that ShapeBit includes keep their own licenses.

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

- **The installer**: the sources of everything on it, including the system
  it installs, are
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
Attribution-ShareAlike 4.0 International
license](https://creativecommons.org/licenses/by-sa/4.0/) (CC BY-SA 4.0).

## Brand identity

The ShapeBit logo, wordmark, mascot, and other original brand artwork are
copyrighted and are not covered by any of ShapeBit's open licenses.
You may pass them on only unmodified, inside an unmodified copy of ShapeBit OS
or its installer; a modified version must remove or replace them and must not
be called ShapeBit. Settings > Licenses shows these terms beside ShapeBit's
licenses, as `LICENSE-Brand.txt`. The ShapeBit name and logo may also be protected under applicable
trademark law. No trademark rights are granted by the software or
documentation licenses.
