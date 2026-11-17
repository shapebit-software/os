# Licenses

The license texts of everything installed, and their reader in Settings >
Licenses: the package `shapebit-licenses`.

Every file under `/usr` comes from an RPM, so the RPM database is the complete
list of what the system contains, and each entry brings its license, its
source, and its SBOM entry. [licenses](licenses) shows each component's texts,
from `/usr/share/licenses/` and from what the RPM database knows elsewhere,
such as a Python package's metadata. ShapeBit's own license, [LICENSE](LICENSE),
is installed under `/usr/share/licenses/shapebit/` and is every own package's
`%license`. The texts of the extras are part of the system, so they are there
before a model is downloaded.

Some Fedora packages leave out a notice that their license asks to keep, or
install no text at all; [notices.py](notices.py) adds it from the package's
exact source RPM. An image test fails on an installed package without a
license text, except those with nothing to license and three whose text isn't
in their source package (ca-certificates, microcode_ctl, shim-x64), reported
to Fedora.

## Adding a dependency

Its license texts come in the same change:

- **Software that Fedora lacks** is an external package
  ([packages/repositories](../repositories/README.md)), with each bundled
  library's texts as `%license` and a `Provides: bundled(...)`.
- **An extra** has its texts in `packages/extras/licenses/<id>/`, listed in
  its `licenses` in `packages/extras/extras.json`, including `<id>/NOTICE`,
  which `extra` writes from its `credits`; each credit's `license` is an SPDX
  ID.
- **A Fedora package that lacks a notice** gets a rule in `notices.py`, which
  goes when Fedora ships the notice.
- **A fixed text**, such as the font's, is committed unchanged in the feature
  that installs it, such as `packages/font/OFL.txt`.
