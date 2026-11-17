# Distribution

The OS as a whole: this folder builds the image from every package of
[`packages/`](../packages/), seals and signs it, installs it with the
installer, and checks the result. What each feature does is in its own
folder; how a release reaches computers is in [release/](release/README.md).
The commands are in the [README](../README.md#usage) at the root.

## Build

`make image` ([image.sh](image.sh)) builds in two phases:

1. [Containerfile](Containerfile) reads every spec's `Requires`, installs
   them, then builds every package at the image's version and commit, with
   every time in them the commit's, so a commit always gives the same
   packages; rpmlint checks them. dnf installs no weak dependencies, so every
   package is there because a spec requires it.
   [packaged.py](packaged.py) fails the build on a file under `/usr` that no
   RPM owns, or that differs from its RPM. The image ships no AI model, and
   `generic-logos` replaces Fedora's, as Fedora's trademark guidelines ask.
2. [Containerfile.seal](Containerfile.seal) adds the signed UKI, whose command
   line pins the system's composefs digest and which carries signed PCR 11
   values ([packages/boot](../packages/boot/README.md)).

The result is `build/image.tar`. `make installer` builds the medium
([packages/installer](../packages/installer/README.md#medium)).

## Signing keys

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
  before tests run ([test_workflows.py](../.github/test_workflows.py)).
  Inside a build, only the steps that sign see them, as build secrets.
- Promotion never re-signs, so a development build can never become a
  release. Whoever can approve a release can ship code to every computer.
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

**Rotation** (planned; it needs code in a release that runs on every machine):

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

## Machines

`make disk` ([vm/disk.sh](vm/disk.sh)) installs the way a person does: it
boots the medium in QEMU with an empty disk of `DISK_SIZE`, checks the medium
([medium/](medium/)), and installs through `installerctl`, the command-line
client of the installer's D-Bus interface. It never builds a disk any other
way. `make installer-vm` opens the same VM in a window.

The VM's EFI variables (`build/efivars.fd`) and TPM state (`build/tpm/`)
belong to the machine, which the medium and the disk share; `make disk`
resets them. [vm/mok-enroll.sh](vm/mok-enroll.sh) accepts the MOK on the VM,
whose firmware starts with Microsoft's keys.

**Development access.** Images and disks contain no credentials. `make disk`,
`make vm`, and `make test` generate an SSH key in `build/ssh/` and pass it as
the systemd credential `ssh.authorized_keys.root`. `make disk` gives the
installer the first owner, `OWNER_NAME`, with the password in
`build/owner-password`, and `LOCALE`, `KEYBOARD_LAYOUT`, and `TIME_ZONE`; the
recovery key goes to `build/recovery-key`. There is no root password.

**Updates from a local build.** `make publish` ([update/publish.sh](update/publish.sh))
pushes the image to a registry container on the host. The VM marks it
insecure, as it serves plain HTTP, and switches to it through `10.0.2.2`:

```bash
printf '[[registry]]\nlocation = "10.0.2.2:5000"\ninsecure = true\n' \
  >/etc/containers/registries.conf.d/50-dev-registry.conf
bootc switch 10.0.2.2:5000/shapebit-os:dev
```

**Real hardware.** A medium built locally is signed with the development
keys; later updates from `stable` would need the release keys enrolled too.
Write `build/installer.img` to a USB drive of at least 8 GB with `dd`, and
install as the [guidebook](../guidebook/Install.md) says. To run the system checks
on it, log in on a console (Ctrl+Alt+F3), connect to the network, allow root
to log in with `build/ssh/id_ed25519.pub`, and run
`make test-guest GUEST=ADDRESS IMAGE_DIGEST=sha256:... OWNER_NAME=... LOCALE=... KEYBOARD_LAYOUT=... TIME_ZONE=...`.
On the medium, `journalctl -b -u installer-backend.service` shows the
installation.

## Testing

| Level | What it tests | Command |
| --- | --- | --- |
| Static | Lint and validate; nothing is built or run | `make static-checks` |
| Unit | Logic that needs no image or VM: `test_*.py` and `tst_*` beside the code | `make test-unit` |
| Image | The image's files; nothing boots ([content/](content/)) | `make test-image` |
| 1. Scripted | The booted medium, the installed system, updates and rollback | `make test`, `make test-update` |
| 2. Full OS and UI | The medium through its UI, then using the system ([openqa/](openqa/)) | `make test-release` |
| 3. AI exploration | Reserved: an agent that explores disposable VMs; each bug it finds must become a level 1 or 2 test | |

A disk result says nothing about the installer's pages, and `make
test-release` covers less of the system's details: a release needs both. The
system checks and openQA compare the running image's digest with the recorded
one, so a result can't describe another build. Every VM attaches the medium
as a snapshot, so it stays byte for byte what `build/installer.img.json`
records. Each run leaves `build/results/<time>-<plan>/`.

### In CI

| Workflow | Starts | Does |
| --- | --- | --- |
| Verification | Every push and pull request | Static checks, then unit tests, then, when the image's inputs change, image tests with a throwaway key; each stage only if the one before passed |
| Candidate | Weekly (Monday, UTC), or by hand | Builds the image without a cache, signed with the release keys, with its sources and SBOM; installs `stable` with `os/installer:stable`, updates it to the candidate, runs level 1 and openQA's desktop modules (`FLOW=update`); if all pass, drafts the release |
| Release | By hand | Copies the candidate to `os:<version>` and `os:stable`, or undoes the last release ([release/](release/README.md)) |
| Installer | Monthly (the 1st, UTC), or by hand | Builds the installer from `os:stable`, runs levels 1 and 2 in full (`FLOW=install`), and after approval publishes it |

So each week a new OS, tested on the path existing computers take, and each
month a new installer, from the OS that is out. An installer bug is fixed by a
Candidate and a Release, then an Installer run. Candidate's **Bootstrap**
skips the update tests while no installer exists yet.

A flaky test job can be re-run with "Re-run failed jobs": the jobs pull what
the build pushed, so the digest doesn't change. Actions artifacts hold test
results only: anyone signed in can download them, and a release-signed image
must not be public before it is released.

### Level 1: tmt

This folder is tmt's tree, with its plans in [plans.fmf](plans.fmf):
`/plans/medium` (run by `make disk`), `/plans/installed` (`make test`), and
`/plans/update` (`make test-update`). To add a check, write a `test_*`
function in a `check_*.py` of the fitting folder; a new file needs an entry
in that folder's `main.fmf`.

- **Machines.** [vm/test-machine.sh](vm/test-machine.sh) clones the installed
  machine for each plan (a disk overlay with copies of its EFI variables and
  TPM state), runs tmt with `provision --how connect`, and discards the
  clone. tmt's testcloud would make a new firmware and TPM, which an
  installed disk can't boot with.
- **The guest** gets only tmt's tree, with pytest and Testinfra
  ([requirements.txt](requirements.txt)); nothing is installed in the system.
- **Reboots.** A test that reboots is a script that picks its stage from
  `TMT_REBOOT_COUNT` and calls `tmt-reboot`; pytest markers name the stages.
- **Updates.** `make test-update` moves a clone to `NEXT_ARCHIVE`'s build,
  checks it, then to `NEXT2_ARCHIVE`'s, and rolls back. The test moves the tag
  that the system follows through the local registry's API, so the host
  needn't act between boots.
- **The recovery key** stays on the host:
  [installed/check_recovery_key.py](installed/check_recovery_key.py) passes it
  over standard input after tmt finishes.
- **After failure**, the plan's `finish` step saves the journal, failed
  units, and `bootc status`.

### Level 2: openQA

[openqa/](openqa/) is an openQA test distribution, run without a server by
isotovideo in a container (`openqa.sh`). Modules are Python; `main.pm` lists
them, in the order `FLOW` chooses. The update flow installs with the
published installer, so needles from the commits it was built from go along
(`run.py needles`).

- Each module pairs what the screen shows (`assert_screen`) with the state
  beneath it (`lib/sut.py`, over SSH): a check that only looks would pass on
  a right picture of a wrong system.
- Use a needle only where the picture is what is tested. Elsewhere, wait on
  state, such as `Installer page: <name>` in the journal. When the UI changes
  on purpose, change its needle in the same commit.
- After failure, `pool/testresults/` keeps each step's screenshot, and
  `pool/` the log and `video.webm`.

## Not yet implemented

- Trial boots with automatic rollback ([packages/updates](../packages/updates/README.md)).
- NvPCR measurements: since systemd 262 they are initialized only from the
  initrd, through a PCR policy signed for it (`ukify --sign-initrd-pcrs`),
  which the UKI doesn't have yet. The TPM policy doesn't use them.
- A minimal signed recovery UKI.
