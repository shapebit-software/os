# Licensing

Everything the system installs keeps its license texts in
`/usr/share/licenses/<component>/`, which Settings > Licenses lists and shows.
They come from four places:

| From | What |
| --- | --- |
| The RPMs | Each package's own texts. Fedora puts most there itself. |
| [`image/rootfs/usr/share/licenses/`](../image/rootfs/usr/share/licenses/) | Fixed texts committed to the repository: ShapeBit's own license (a copy of [`LICENSE.md`](../LICENSE.md)) and the font. |
| [`desktop/extras/licenses/`](../desktop/extras/licenses/) | The texts of the models that are extras, installed by the desktop. |
| The image build | `collect.py`: the notices that some RPMs lack, from their exact source RPMs (`rpms.json`), and links to RPM license files kept elsewhere. |

| File | Purpose |
| --- | --- |
| `rpms.json` | The notices to take from source RPMs, and documents to link. |
| `collect.py` | Build-time collection; source RPMs stay in the build stage. |
| `read.py` | The reader Settings > Licenses uses, installed as `/usr/libexec/desktop/licenses`. |

User-facing licensing, source and SBOM information is in
[`docs/License.md`](../docs/License.md). Source RPM publication is in
`scripts/sources.py`; the SBOM is `scripts/sbom.py` (`make sbom`).

## Add or update a component

Add its license text in the same change as the dependency:

- **Software that Fedora lacks**: package it in [`third-party/`](../third-party/), with each
  bundled library's texts as `%license` and its `Provides: bundled(...)`; the
  RPM then brings its texts, sources and SBOM entries like any other.
- **A fixed text** (a font): commit it under
  `image/rootfs/usr/share/licenses/<component>/`, unchanged from upstream, with
  its copyrights, conditions and disclaimers.
- **An extra**: commit its texts under `desktop/extras/licenses/<id>/`, list them in its `licenses` in `desktop/extras/extras.json`,
  including `<id>/NOTICE`, which is `extra`'s notice of its `credits`; each
  credit's `license` is an SPDX license ID. Unit tests check that each text
  exists and that NOTICE matches.
- **An RPM that lacks a notice**: add a rule to `rpms.json` naming the binary
  package, the archive in its source RPM, and the file in it. A notice at the
  start of a source file uses `"header": true`. A wildcard matches one path
  component, and exactly one file must match, or the build fails.

## Verify

- `make test-unit` inside `make dev`: the collector, the reader, and that each
  committed text matches what it covers.
- `make test-image`: the installed notices, and the Settings reader and viewer.
- `make test`: the installer keeps them.
