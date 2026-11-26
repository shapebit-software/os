# Distribution

How a build reaches people: how it becomes a release, reaches computers, and
is undone, and what is published with it so that it can be trusted, its
licenses kept, and its contents known. The workflows are in
[.github/workflows](../.github/workflows/); each of their steps with GHCR and
GitHub's releases is a command of [release.py](release.py); what each decides
is tested beside its part. It needs only Python, skopeo, `gh`, and the engine, so
the jobs that only release run it on the runner, without the development image.

| Path | What it is |
| --- | --- |
| `release.py` | The command line that the workflows call; only that. |
| `candidate.py` | A candidate: pushed to `os/candidate` with its sources and SBOM, then its draft release, notes, and record. |
| `channel.py` | `os:stable`, which computers update from: promote (sign, verify as computers do), undo, prune. |
| `medium.py` | The installer medium: the OS it carries, pushing it with its sources, the download server's files, pulling one for the tests. |
| `common.py` | What they share: the GHCR packages, the trust files, commands, skopeo copies, GitHub's releases. |
| `oci.py` | OCI artifacts of plain files, pushed and pulled with [ORAS](https://oras.land) from its pinned image; registry digests. |
| [sources/](sources/README.md) | The source RPMs of each build, which the licenses ask for. |
| [sbom/](sbom/README.md) | The software bill of materials of each build, for license reviews and security scanners. |

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
other than `stable`'s and the one before, with their sources, SBOMs and
signatures (`release.py prune`).

## Steps

1. **Build.** Weekly or by hand, a fresh build picks up Fedora's updates and
   is signed with the release keys ([keys](../image/keys/README.md)).
2. **Test** on the path installed computers take: the published installer
   installs `stable`, which updates to the candidate
   ([Testing](../README.md#testing)). Only a build that passes everything
   gets a draft release: its notes, its packages, and its record
   (`record.json`), which names the image, its sources and its SBOM by digest,
   and keeps the signature policy, key, and `registries.d` that the image ships.
3. **Try.** A person reads the notes and can try the candidate on a real
   computer.
4. **Release.** A person starts Release, which copies what the record names,
   unchanged, to its version, signs the image with the release image key,
   checks the signature as computers do, with the policy and key from the
   record, moves `stable` to it, and publishes
   the notes. Computers accept updates only with that signature
   ([packages/updates](../packages/updates/README.md#signed-updates)).
   Promotion never re-signs boot files.
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

## Planned

- **Signed release record**: the record, signed, with the UKI and root
  digest, so that the updater checks a release's whole identity, not only its
  image's signature.
- **Revocation**: a release unsafe to boot is abandoned even if staged, with
  signed revocation records that apply offline.

Before anyone outside ShapeBit's test machines installs: back up the release
keys offline; require hardware security keys or passkeys in the GitHub
organization; protect `main` and require a reviewer to release; let updates
replace shim.

Before a public release: move the release keys to hardware-backed signing;
replace the Hyprland COPR ([packages/repositories](../packages/repositories/README.md));
get ShapeBit's own shim signed by Microsoft, including with the 2023
certificate; test on a range of real PCs.
