# Packages

What the OS is made of: one folder per feature, each a package,
`shapebit-<folder>`, with everything about the feature. `system` requires
every feature. [image/](../image/README.md) builds them into the images.

Every feature has the same layout, with only the folders it needs:

| Path | What it holds |
| --- | --- |
| `<folder>.spec`, `Makefile`, `README.md` | The package: its spec, its install rules (CMake for the installer), and what the code can't say. |
| `src/` | What runs: programs, modules, QML, JavaScript, Lua. |
| `system/` | How the OS runs it: systemd units, presets, tmpfiles, sysusers, and other configuration. |
| `data/` | What it reads: catalogs, images, fonts, license texts. |
| `tests/` | Its unit tests (`test_*`, `tst_*`) and the checks of the built OS (`check_*.py`, [quality/](../quality/README.md)). |
| `tools/` | What serves the feature but is never installed, such as a generator or a publishing script. |
| `external/` | External packages, below. |

The `Makefile` installs every file of `src/`, `system/` and `data/`, and
nothing else ([test_install.py](test_install.py)).

| File | What it is |
| --- | --- |
| [package.macros](package.macros), [package.mk](package.mk) | What every spec and every feature's `Makefile` share: the version, the paths, the license. |
| [requires.sh](requires.sh) | What the specs require from Fedora and the repositories, which the foundation installs. |
| [rpmbuild.sh](rpmbuild.sh) | Builds the packages in the image build, at the image's version and commit, reproducibly. |
| [rpmlint.toml](rpmlint.toml) | The rpmlint findings that are accepted, and why. |
| `test_*.py` | That every file is installed, every unit parses, and every feature is required. |

Software that Fedora lacks is an external package in the `external/` of the
feature that needs it, such as `dictation/external/sherpa-onnx/`, built and published apart
([repositories](repositories/README.md)).
