# Release

How a build becomes a release, reaches computers, and is undone; and what is
published with it. The workflows are in [.github/workflows](../../.github/workflows/).

## Versions and channels

ShapeBit is a rolling release. A version is the time its build started, in
UTC, such as `202610301530`, recorded as `IMAGE_VERSION` in
`/usr/lib/os-release` and in the image label
`org.opencontainers.image.version`; local builds are `dev`. Installed systems
update from `ghcr.io/shapebit-software/os:stable`, which the installer
records.

| Package on GHCR | Visibility | Tags | Holds |
| --- | --- | --- | --- |
| `os` | Public | `stable`, `<version>`, `-sources`, `-sbom` | Released images; computers update from `stable` |
| `os/candidate` | Private | `<version>`, `-sources`, `-update` | Images under test, and the build the update test moves on to |
| `os/installer` | Private | `<version>`, `-sources`, `stable` | Installer media as OCI artifacts; `stable` is the one on the download site |

Both private packages give this repository's Actions write access (Package
settings > Manage Actions access). Each Release deletes the versions of `os`
other than `stable`'s and the one before, with their sources
([prune-packages.py](prune-packages.py)).

## Steps

1. **Build.** Weekly or by hand, a fresh build picks up Fedora's updates and
   is signed with the release keys.
2. **Test** on the path installed computers take: the published installer
   installs `stable`, which updates to the candidate
   ([Testing](../README.md#testing)). Only a build that passes everything
   gets draft release notes ([release-notes.py](release-notes.py)).
3. **Try.** A person reads the notes and can try the candidate on a real
   computer.
4. **Release.** A person copies the candidate, unchanged, to its version and
   to `stable`, and the notes are published. Promotion never re-signs.
5. **Undo, if needed.** `stable` moves back to the release before, which is
   marked **withdrawn**, and computers take it as their next update. A
   withdrawn build can't be released again.

One installer is built per release, monthly, from `stable`, tested in full,
and published after approval to
[download.shapebit.software](https://download.shapebit.software/shapebit-installer.img.xz).
To fix the installer, a new release comes first.

Third-party software comes from Fedora (into the image), and from Flathub and
Fedora's Flatpaks (onto the computer); ShapeBit mirrors none of it.
ShapeBit's own apps, when there are any, will be published in a Flatpak
repository of its own, built with [AetherPak](https://github.com/aetherpak/actions).

## Sources and SBOM

Sources are collected while the image is built, when Fedora's repositories
still match it, and published before or with it, for as long as that version
can be downloaded: the source RPM of every installed package that has one,
regardless of its license label ([sources.py](sources.py)), as the OCI
artifact `<version>-sources`, which the image label `software.shapebit.sources`
names. The Sources workflow collects them for a released version that has
none.

The SBOM ([sbom.py](sbom.py)) lists the RPMs and Python packages that syft
finds, the code each RPM declares it bundles (`Provides: bundled(...)`),
ShapeBit itself, and the downloadable models as optional components; its RPMs
are checked to be exactly the installed ones. `make sbom` writes it for a
local image.

## Planned

- **Release manifest**: one signed, immutable manifest per release, binding
  the version, image digest, UKI, and root digest. Channels then point to
  manifests, and the updater accepts only what matches one. Until then, a
  release is identified by its image digest, and an update is accepted by
  where it comes from; Secure Boot still checks its UKI.
- **Revocation**: a release unsafe to boot is abandoned even if staged, with
  signed revocation records that apply offline.

Before anyone outside ShapeBit's test machines installs: back up the release
keys offline; require hardware security keys or passkeys in the GitHub
organization; protect `main` and require a reviewer to release; sign release
images, with computers refusing others; let updates replace shim.

Before a public release: move the release keys to hardware-backed signing;
replace the Hyprland COPR ([packages/repositories](../../packages/repositories/README.md));
get ShapeBit's own shim signed by Microsoft, including with the 2023
certificate; test on a range of real PCs.
