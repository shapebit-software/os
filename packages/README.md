# Packages

What the OS is made of: one folder per feature, each a package,
`shapebit-<folder>`, with everything about the feature. `system` requires
every feature. [image/](../image/README.md) builds them into the images.

Every feature has the same layout, with only the folders it needs:

| Path | What it holds |
| --- | --- |
| `<folder>.spec`, `Makefile`, `README.md` | The package: its spec, its install rules (CMake for the installer), and what the code can't say. |
| `Cargo.toml` | Its Rust programs, whose sources are in `src/` ([packaging](packaging/README.md)'s cargo.mk). |
| `src/` | What runs: programs, modules, QML, JavaScript, Lua. |
| `system/` | How the OS runs it: systemd units, presets, tmpfiles, sysusers, and other configuration. |
| `data/` | What it reads: catalogs, images, fonts, license texts. |
| `tests/` | Its tests, arranged as it likes, each level by its markers; and `e2e/`, its openQA modules ([testing](testing/README.md)). |
| `tools/` | What serves the feature but is never installed, such as a generator or a publishing script. |
| `external/` | External packages, below. |

The `Makefile` installs every file of `src/`, `system/` and `data/`, but
Rust sources, which it builds, and nothing else (`make check-package`).

Three packages are the tools that every package is built, checked, and
tested with, which only the development image has, and whose code runs from
the tree there ([image/requires.sh](../image/requires.sh) `--tools`):

| Package | What it is |
| --- | --- |
| [packaging](packaging/README.md) | How a package is built: the macros that every spec loads, what every `Makefile` includes, and the license texts. |
| [linting](linting/README.md) | How code is checked without running it (`make lint`). |
| [testing](testing/README.md) | How everything is tested: the levels, the fixtures, the machines, openQA. |

`make check-package`, in a package's folder, checks what every package
keeps to: its spec is named for its folder, its Makefile installs every file
and no test, its License names its files' licenses, and its units parse
([conformance.py](packaging/src/conformance.py)); packaging's tests run it on
every package here. That shapebit-system requires every feature is system's
own test, and that external packages are pinned is repositories'.

**Every package could live in a repository of its own** and still build and
test, with the tools installed: its `Makefile` includes `$(PACKAGING)/package.mk`,
never `../`; its spec loads `%{load:%{shapebit_macros}}`; its tests find its
files with `package_dir(__file__)` and another package's with
`sibling(NAME, __file__)`, which skips where the package is alone; and
`make test-unit` and `make test-integration` run in its own folder.
[test_layout.py](testing/tests/test_layout.py) holds every package to
it, and the image build proves it: its standalone stage builds and tests a
package away from this tree, with only the tools installed.

A runtime piece that several features share, such as a QML module, is a
package of its own that they require, as Colors is.

Software that Fedora lacks is an external package in the `external/` of the
feature that needs it, such as `dictation/external/sherpa-onnx/`, built and published apart
([repositories](repositories/README.md)).
