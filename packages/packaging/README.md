# Packaging

How a ShapeBit package is built. Every feature's Makefile includes
`package.mk`, and every spec loads `package.macros`; shapebit-packaging
installs them, so that a package can be built outside this repository too. No
OS image has it.

| File | What it is |
| --- | --- |
| `src/package.macros` | What every spec shares: the version, the release, the licenses, and `%shapebit_install`, which installs a feature with its Makefile and lists its files. |
| `src/package.mk` | What every feature's Makefile shares: the install paths and `help`. |
| `src/cargo.mk`, `src/crates.py` | What every feature with Rust programs shares: building them offline with Fedora's crates, their tests, and the crates' licenses and texts. |
| `src/conformance.py` | What every package keeps to, checked on one package (`make check-package`): its files installed, no test installed, its License, its units. |
| `data/rpmlint.toml` | The rpmlint findings that are accepted, and why. |
| `data/licenses/` | Every license text of the repository, which its root `LICENSES` links to; each package installs those of ShapeBit's own licenses that its License names. |
| `data/macros.shapebit` | Where the installed macros and texts are (`%shapebit_macros`, `%shapebit_licenses`). |

**Here or installed.** A feature's Makefile finds the kit with `PACKAGING`:
this tree's `src/` when it is there, else `/usr/share/shapebit/packaging`. A
spec loads `%{load:%{shapebit_macros}}`, which shapebit-packaging defines, and
which the image build points to this tree ([rpmbuild.sh](../../image/rpmbuild.sh)).
Only those two paths are defined for every rpmbuild where the package is
installed; the macros themselves apply only to the specs that load them.

**Versions.** In an image build, every package has the image's version.
Without one, `%shapebit_version` is 0.

The image build builds shapebit-packaging and installs it in a stage of its
own on the foundation, where it builds a feature away from this tree
([image/Containerfile](../../image/Containerfile), the standalone stage).
