# Third-party packages

ShapeBit builds what the image needs and Fedora lacks as RPMs, so it installs
like any other package: its license texts reach `/usr/share/licenses`, its
source RPM reaches the published sources (`scripts/release/sources.py`), and what it
bundles reaches the SBOM (`scripts/release/sbom.py` reads `Provides: bundled(...)`).

| Package | Why |
| --- | --- |
| `llama-server` | The assistant's language model server, from llama.cpp; Fedora's `llama-cpp` is too old for Gemma 4. Its libraries stay private in `/usr/libexec/llama`. |
| `sherpa-onnx` | Dictation's speech recognition; Fedora has no package. Built against Fedora's ONNX Runtime, not upstream's bundled copy. |

## How it works

- Each package is a directory: `NAME/NAME.spec` and `NAME/sources`, the SHA-512
  of each of its Sources, as in Fedora's package repositories. Upstream downloads during its build become Sources,
  so the build runs without network and the source RPM holds all the code.
- `make rpm RPM=NAME` builds one into `build/rpms/NAME`, in a Fedora container
  of `FEDORA_VERSION` (`scripts/build/rpm-build.sh`).
- The workflow [Third-party packages](../.github/workflows/third-party.yml) runs when `third-party/`
  changes on `main`. A version that has no release yet becomes the release
  `rpm-NAME-VERSION-RELEASE`, with the binary and source RPMs as assets. It
  then writes the repository of all those releases, signed
  (`scripts/release/rpm-repo.sh`), and deploys it to GitHub Pages:
  `https://shapebit-software.github.io/os/rpms/fedora-VERSION-{x86_64,source}/`.
- The image build and `scripts/release/sources.py` read it through
  `image/third-party.repo`. dnf checks the repository's signature with
  `image/third-party.asc`; the metadata holds each RPM's SHA-256.

## Add or update a package

1. Write or change the spec. Bump `Release` for a rebuild of the same version;
   a new upstream version resets it to 1.
2. Download its Sources and write their hashes to `sources`, in Fedora's
   format: `spectool -g NAME.spec`, then `sha512sum --tag FILE... > sources`.
3. `make rpm RPM=NAME`, then test what it built in a container of the image's
   Fedora version.
4. Require it in the spec that needs it (`desktop/desktop.spec` or
   `system/system.spec`), and merge: the workflow publishes it before the next image
   build can use it.

## The signing key, once

Create the key on your own computer, put the private key in the environment
"Signing" as the secret `RPM_SIGNING_KEY`, and commit the public key:

```sh
export GNUPGHOME=$(mktemp -d)
gpg --batch --passphrase '' --quick-gen-key "ShapeBit packages" ed25519 sign never
gpg --armor --export > image/third-party.asc
gpg --armor --export-secret-keys | gh secret set RPM_SIGNING_KEY --env Signing
rm -rf "$GNUPGHOME"
```

Then, in the repository's settings, set Pages' source to GitHub Actions.
