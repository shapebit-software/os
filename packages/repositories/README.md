# Repositories

Where the system's packages come from beside Fedora's, and how ShapeBit
publishes the ones it builds itself. The package `shapebit-repositories`
ships the repositories, turned off on installed systems, with the key and
dnf's settings; the image build turns them on.

| File | What it is |
| --- | --- |
| `hyprland.repo` | The third-party COPR that Hyprland comes from, for now ([below](#hyprland)). |
| `third-party.repo`, `third-party.asc` | ShapeBit's own repository of external packages, and the key that signs it. |
| `no-weak-deps.conf`, `no-countme.repo` | dnf installs no weak dependencies, and does not report the computer to Fedora's mirrors. |
| `rpm-build.sh`, `rpm-repo.sh` | Build an external package, and write the signed repository of them all. |

## Hyprland

Fedora has no Hyprland, so Hyprland, its dialogs, hypridle,
xdg-desktop-portal-hyprland, and Quickshell come from the
[sdegler/hyprland](https://copr.fedorainfracloud.org/coprs/sdegler/hyprland/)
COPR. This is a known supply-chain risk: one person controls it, its package
scripts run as root during the image build, and a newer version of any Fedora
package in it would be installed instead. What limits it: packages are checked
against the COPR's key; installed systems ship it turned off, so they never
fetch from it; the source RPMs are kept with each release's sources. Drop it
as soon as Fedora ships Hyprland: remove `hyprland.repo` and the COPR from
`development/distrobox.ini`.

## External packages

ShapeBit builds what the image needs and Fedora lacks as RPMs, so it installs
like any other package: its license texts reach `/usr/share/licenses`, its
source RPM reaches the published sources (`distribution/release/sources.py`), and
what it bundles reaches the SBOM (`distribution/release/sbom.py` reads
`Provides: bundled(...)`). Each lives in the feature that needs it, which
requires it:

| Package | Where | Why |
| --- | --- | --- |
| `llama-server` | `packages/assistant/llama-server/` | The assistant's language model server, from llama.cpp; Fedora's `llama-cpp` is too old for Gemma 4. Its libraries stay private in `/usr/libexec/llama`. |
| `python3-sherpa-onnx` | `packages/dictation/sherpa-onnx/` | Dictation's speech recognition; Fedora has no package. Built against Fedora's ONNX Runtime, not upstream's bundled copy. |

### How it works

- **An external package is a folder with a `sources` file:** `NAME/NAME.spec`
  and `NAME/sources`, the SHA-512 of each of its Sources, as in Fedora's
  package repositories, below the feature that needs it. ShapeBit's own
  packages have no `sources` file; they are built from the repository.
  Upstream downloads during its build become Sources, so the build runs
  without network and the source RPM holds all the code. A patch goes beside
  the spec, as `PatchN:`.
- `make rpm RPM=packages/FEATURE/NAME` builds one into `build/rpms/NAME`, in a
  Fedora container of `FEDORA_VERSION` (`rpm-build.sh`), and checks it with
  rpmlint.
- The workflow [Third-party packages](../../.github/workflows/third-party.yml)
  runs when one changes on `main`. A version that has no release yet becomes
  the release `rpm-NAME-VERSION-RELEASE`, with the binary and source RPMs as
  assets; anything else changing builds nothing. It then writes the
  repository of all those releases, signed (`rpm-repo.sh`), and deploys it to
  GitHub Pages:
  `https://shapebit-software.github.io/os/rpms/fedora-VERSION-{x86_64,source}/`.
- The image build and `distribution/release/sources.py` read it through
  `third-party.repo`; dnf checks the repository's signature with
  `third-party.asc`; the metadata holds each RPM's SHA-256. `make validate`
  checks each external package's `License` against Fedora's list.

### Add or update a package

1. Write or change the spec, in a folder named after the package inside the
   feature that needs it. Bump `Release` for a rebuild of the same version; a
   new upstream version resets it to 1. (Fedora's `%autorelease` counts the
   commits of a package's own repository; in a folder of this one it cannot.)
2. Download its Sources and write their hashes to `sources`, in Fedora's
   format: `spectool -g NAME.spec`, then `sha512sum --tag FILE... > sources`.
3. `make rpm RPM=packages/FEATURE/NAME`, then test what it built in a container
   of the image's Fedora version.
4. Require it in the feature's spec, and merge: the workflow publishes it
   before the next image build can use it.

### The signing key, once

Create the key on your own computer, put the private key in the environment
"Signing" as the secret `RPM_SIGNING_KEY`, and commit the public key:

```sh
export GNUPGHOME=$(mktemp -d)
gpg --batch --passphrase '' --quick-gen-key "ShapeBit packages" ed25519 sign never
gpg --armor --export > packages/repositories/third-party.asc
gpg --armor --export-secret-keys | gh secret set RPM_SIGNING_KEY --env Signing
rm -rf "$GNUPGHOME"
```

Then, in the repository's settings, set Pages' source to GitHub Actions.
