# Signing

In the pipeline: [keys.sh](keys.sh) makes the development keys in
`build/keys/` for `make image`, and the release keys once with `make
release-key`; the image build signs the boot files with them, and
[distribution](../distribution/README.md) the released image.

What makes a build ShapeBit's: the keys that sign it, how they are kept, and
how they are replaced. The image build uses them when it seals
([images](../image/README.md#build)); this file owns the policy.

A build is signed with two keys of `SIGNING_KEY`, so that each can be
replaced on its own:

| Key | Signs | If it leaks |
| --- | --- | --- |
| Secure Boot (`*-secureboot.key`, `.crt`, the MOK people enroll) | systemd-boot and the UKI | Its holder can boot their code on every machine that enrolled it; without the PCR key, the TPM still refuses to unlock the disk. |
| PCR (`*-pcr.key`) | The expected PCR 11 values in each UKI | Alone, nothing boots. |

- **Development keys** (`dev-*`, "ShapeBit Development") are generated in
  `build/keys/` by [keys.sh](keys.sh). The checks of pushes and pull requests
  use throwaway ones. They are trusted only by the developer's machines.
- **Release keys** ("ShapeBit") sign every candidate, so every release.
  `make release-key KEYS_DIR=<directory>` generates them once; builds never
  do. They are the secrets `RELEASE_SECUREBOOT_KEY` and `RELEASE_PCR_KEY` of
  the GitHub environment **Signing**, used only by the build jobs of the
  Candidate and Installer workflows on `main`, and removed from the runner
  before tests run ([test_workflows.py](../.github/tests/test_workflows.py)).
  Inside a build, only the steps that sign see them, as build secrets.
- **The release image key** (`release-image.key`, sigstore, made by
  `make release-key` with no passphrase) signs each release's image as the
  Release workflow promotes it; computers accept updates only with its
  signature ([packages/updates](../packages/updates/README.md#signed-updates)).
  It is the secret `RELEASE_IMAGE_KEY` of the environment **Release**, a file
  on the runner only while `release.py promote` runs
  ([test_workflows.py](../.github/tests/test_workflows.py)); its public half,
  `packages/updates/data/release-image.pub`, is committed, and every build trusts it.
  If it leaks, its holder can offer updates that computers accept, but only
  from `ghcr.io/shapebit-software/os`, and they boot only if Secure Boot's key
  signed them too. To replace it: release a build that trusts both keys,
  then one that trusts the new key only.
- Promotion never re-signs boot files, so a development build can never become
  a release. Whoever can approve a release can ship code to every computer.
- Both are RSA-2048, which shim and every TPM accept. Firmware and shim don't
  check certificate dates; replacing a key retires it.
- An installer enrolls the TPM with the PCR key of its own UKI, so an
  installer and the release it carries share the PCR key.

**Limit.** During those builds the keys are files on a GitHub-hosted runner,
which also runs the packages' scripts. Next: sign in jobs that receive only
unsigned binaries, or through PKCS#11 from a KMS or HSM (`sbsign` and `ukify`
support it); it takes two rounds, because the signed systemd-boot is in
`/usr`, inside the digest that the UKI pins. The goal is an offline root key
that delegates to release, boot, PCR, and repository keys in hardware-backed
storage.

## Rotation

Planned; it needs code in a release that runs on every machine.

- *PCR key*: release a UKI whose PCR 11 values are signed with both keys
  (`ukify` takes several `--pcr-private-key`), with a one-time service that
  enrolls a TPM slot for the new key with `systemd-cryptenroll` and wipes the
  old one. Once every machine has run it, sign with the new key only. A
  machine that missed it asks for its recovery key once.
- *Secure Boot key*: release a build, still signed with the old key, that
  queues the new certificate with `mokutil --import`, which the person
  confirms at the next boot. The same release must enroll a TPM slot for the
  new PCR 7 value (predicted with `systemd-pcrlock`), since shim measures the
  certificate into PCR 7. Then sign with the new key and queue removal of the
  old one (`mokutil --delete`).
- *After a Secure Boot key leak*, nobody can revoke it remotely: every MOK
  change needs the person at the machine. Also queue the old certificate in
  shim's deny list (`mokutil --mokx --import`). This is why the keys stay off
  runners as much as possible and have an offline backup.
