# Licenses

The license texts of everything installed, and their reader in Settings >
Licenses: the package `shapebit-licenses`.

Every file under `/usr` comes from an RPM, so the RPM database is the complete
list of what the system contains, and each entry brings its license, its
source, and its SBOM entry. [licenses](src/licenses) shows each component's texts,
from `/usr/share/licenses/` and from what the RPM database knows elsewhere,
such as a Python package's metadata. ShapeBit's own licenses depend on the
kind of file ([REUSE.toml](../../REUSE.toml)); a package's `License` names
those of the files it installs, with the macros of
[packaging](../packaging/README.md)'s package.macros, such as `%{shapebit_config}`, and
`%shapebit_install` installs the text of each from packaging's `data/licenses/`, as
`/usr/share/licenses/shapebit/LICENSE-<license>.txt`: the same file for every
package that names it. These texts are copies of [LICENSES](../../LICENSES),
which [packaging's test_licenses.py](../packaging/tests/test_licenses.py) keeps the same. The texts of
the extras are part of the system, so they are there before a model is
downloaded.

Some Fedora packages leave out a notice that their license asks to keep, or
install no text at all; [notices.py](tools/notices.py) adds it from the package's
exact source RPM, or, where that holds none, from [data/notices](data/notices),
one folder per package, whose origin notices.py names (such as shim-x64, whose
source RPM holds only signed binaries). An image test fails on an installed
package without a license text, except those with nothing to license.

## Adding a dependency

Its license texts come in the same change:

- **Software that Fedora lacks** is an external package
  ([packages/repositories](../repositories/README.md)), with each bundled
  library's texts as `%license` and a `Provides: bundled(...)`.
- **An extra** has its texts in `packages/extras/data/licenses/<id>/`, listed in
  its `licenses` in `packages/extras/data/extras.json`, including `<id>/NOTICE`,
  which `extra` writes from its `credits`; each credit's `license` is an SPDX
  ID.
- **A Fedora package that lacks a notice** gets a rule in `notices.py`, which
  goes when Fedora ships the notice; if its source RPM lacks it too, the text
  is committed unchanged in `data/notices/<package>/`, with its origin in
  `notices.py`.
- **A fixed text**, such as the font's, is committed unchanged in the feature
  that installs it, such as `packages/font/data/OFL.txt`.
