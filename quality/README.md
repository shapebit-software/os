# Quality

How the built OS is checked. Unit tests and the `check_*.py` of the built OS
live in the `tests/` of the feature they test, in `packages/`; this folder holds what they
share, and the tests that go through the whole OS as a person does.

| Path | What it is |
| --- | --- |
| `machine.py` | The test machines (`make disk`, `make vm`, `make ssh`) and the tests' own settings, such as the first owner. |
| `fixtures.py`, `pytest.ini` | How each `check_*.py` reaches its machine, picked by its marker. |
| `openqa/` | The openQA tests: `main.pm`, `lib/`, `needles/`, and `tests/`, one folder per feature. |

| Level | What it tests | Command |
| --- | --- | --- |
| Static | Lint and validate; nothing is built or run | `make static-checks` |
| Unit | Logic that needs no image or VM: `test_*.py` and `tst_*` in each feature's `tests/` | `make test-unit` |
| Image | The image's files; nothing boots (`check_*.py` marked `image`) | `make test-image` |
| 1. Scripted | The booted medium, the installed system, updates and rollback (`check_*.py` marked `medium`, `installed`, `update`) | `make test`, `make test-update` |
| 2. Full OS and UI | The medium through its UI, then using the system ([openqa/](openqa/)) | `make test-release` |
| 3. AI exploration | Reserved: an agent that explores disposable VMs; each bug it finds must become a level 1 or 2 test | |

A disk result says nothing about the installer's pages, and `make
test-release` covers less of the system's details: a release needs both. The
system checks and openQA compare the running image's digest with the recorded
one, so a result can't describe another build. Every machine attaches the
medium as a snapshot, so it stays byte for byte what `build/installer.img.json`
records. Each run leaves `build/results/<time>-<name>/`.

The test settings, such as the first owner and the locale that the installer
is given, are in [machine.py](machine.py), each overridable from the
environment: `make disk OWNER_NAME=someone`. The build's are in the Makefile.

## In CI

| Workflow | Starts | Does |
| --- | --- | --- |
| Verification | Every push and pull request | Static checks and unit tests of the packages the change touches ([changed.py](../development/changed.py)), then, when the image's inputs change, image tests with a throwaway key; each stage only if the one before passed |
| Candidate | Weekly (Monday, UTC), or by hand | Builds the image without a cache, signed with the release keys, with its sources and SBOM; installs `stable` with `os/installer:stable`, updates it to the candidate, runs level 1 and openQA's desktop modules (`FLOW=update`); if all pass, drafts the release |
| Release | By hand | Copies the candidate to `os:<version>`, signs it, and moves `os:stable` to it, or undoes the last release; then prunes ([distribution](../distribution/README.md)) |
| Installer | Monthly (the 1st, UTC), or by hand | Builds the installer from `os:stable`, runs levels 1 and 2 in full (`FLOW=install`), and after approval publishes it |

A change touches the packages with changed files, and those that depend on
them: whose specs require them, or whose tests read their files. A change
outside `packages/`, or to what all packages share, touches every package;
Candidate and Installer check every package anyway.

So each week a new OS, tested on the path existing computers take, and each
month a new installer, from the OS that is out. An installer bug is fixed by a
Candidate and a Release, then an Installer run. Candidate's **Bootstrap**
skips the update tests while no installer exists yet.

The jobs on VMs are one reusable workflow, `vm-test.yml`. A flaky test job can
be re-run with "Re-run failed jobs": the jobs pull what the build pushed, so
the digest doesn't change. Actions artifacts hold test
results only: anyone signed in can download them, and a release-signed image
must not be public before it is released.

## Level 1: pytest and Testinfra

The checks are `check_*.py` in the folder of what they check, with `test_*`
functions; a new file needs nothing else. pytest runs them in the development
image ([development](../development/README.md)), with KVM; Testinfra
reaches the machine over SSH, so nothing is copied to or installed in the
system under test. The engine, which runs the update registry, is the host's.

- **Machines.** `--machine` chooses what `host` is ([fixtures.py](fixtures.py)):
  `clone`, a disposable clone of the installed machine for each run (a disk
  overlay with copies of its EFI variables and TPM state), which an installed
  disk unlocks only with; `ssh://ADDRESS[:PORT]`, a machine that runs already;
  or `container://IMAGE`, a container of the image with no network, which
  Testinfra reaches through the engine, for the `image` checks. A check reads
  the machine only through `host`, never the files where pytest runs.
- **Reboots.** A check that reboots calls `machine.reboot()`, which waits for
  a new boot; the checks after it see the machine as it came back.
- **Updates.** `make test-update` moves a clone to `NEXT_ARCHIVE`'s build
  ([check_to_next.py](../packages/updates/tests/check_to_next.py)), runs the installed
  system's checks on it, then moves it to `NEXT2_ARCHIVE`'s and rolls back
  ([check_rollback.py](../packages/updates/tests/check_rollback.py)). Both are the image
  under test as other versions ([update.Containerfile](../image/update.Containerfile)),
  sealed again, which `make update-builds` makes in minutes. The checks push
  them to the local registry and move the tag that the system follows through
  its API.
- **The recovery key** stays on the host, and reaches the machine over
  standard input ([check_recovery_key.py](../packages/boot/tests/check_recovery_key.py)).
- **After each run**, the journal, the failed units, `bootc status`, and the
  serial console are kept with the results.

## Level 2: openQA

[openqa/](openqa/) is an openQA test
distribution, run without a server by isotovideo in the development image,
with a network of its own ([run.py](openqa/run.py)). Modules
are Python, in `tests/`, one folder for each feature they test, named as in
`packages/` (`installer/`, `boot/`, `login/`, `settings/`, `windows/`,
`assistant/`, `dictation/`, `updates/`); `main.pm` lists them, in the order
`FLOW` chooses. Their helpers are in `lib/`, their pictures in `needles/`. The update flow installs with the published installer,
whose screens its own release tested: it installs through `installerctl` and
waits on state until the candidate runs, so only the tree's needles are used.

- Each module pairs what the screen shows (`assert_screen`) with the state
  beneath it (`lib/sut.py`, over SSH): a check that only looks would pass on
  a right picture of a wrong system.
- Use a needle only where the picture is what is tested. Elsewhere, wait on
  state, such as `Installer page: <name>` in the journal. When the UI changes
  on purpose, change its needle in the same commit.
- After failure, `pool/testresults/` keeps each step's screenshot, and
  `pool/` the log and `video.webm`.

## Machines

`make disk` installs the way a person does ([machine.py](machine.py)): it
boots the medium in QEMU with an empty disk of `DISK_SIZE`, checks the medium
([check_medium.py](../packages/installer/tests/check_medium.py)), and installs through `installerctl`, the command-line
client of the installer's D-Bus interface. It checks only a medium built from
the tree's commit: a published one, such as the stable medium that the update
test installs, was checked by its own release. It never builds a disk any other
way. `make installer-vm` opens the same machine in a window.

The machine's EFI variables (`build/efivars.qcow2`) and TPM state
(`build/tpm/`) belong to it, and the medium and the disk share them; `make
disk` resets them. On a new machine, the firmware starts with Microsoft's
keys, so shim's MOK manager asks to enroll the image's certificate once;
`machine.py` answers it, as a person would.

**Development access.** Images and disks contain no credentials. The machines
get the SSH key in `build/ssh/` as the systemd credential
`ssh.authorized_keys.root`. `make disk` gives the installer the first owner,
`OWNER_NAME`, with the password in `build/owner-password`, `shapebit` unless
that file holds another, and the
installer's settings; the recovery key goes to `build/recovery-key`. There is
no root password. `make vm` boots the disk in a window; `make ssh` opens a shell in it.

**Updates from a local build.** `make publish` pushes the image to a registry
container of the host's engine (`machine.py publish`), which it starts unless
it runs. The machine marks it insecure, as
it serves plain HTTP, and switches to it through `10.0.2.2`:

```bash
printf '[[registry]]\nlocation = "10.0.2.2:5000"\ninsecure = true\n' \
  >/etc/containers/registries.conf.d/50-dev-registry.conf
bootc switch 10.0.2.2:5000/shapebit-os:dev
```

**Real hardware.** A medium built locally is signed with the development
keys; later updates from `stable` would need the release keys enrolled too.
Write `build/installer.img` to a USB drive of at least 8 GB with `dd`, and
install as the [guidebook](../guidebook/Install.md) says. To run the system
checks on it, log in on a console (Ctrl+Alt+F3), connect to the network,
allow root to log in with `build/ssh/id_ed25519.pub`, and run
`make test-guest GUEST=ADDRESS IMAGE_DIGEST=sha256:... OWNER_NAME=... LOCALE=... KEYBOARD_LAYOUT=... TIME_ZONE=...`.
On the medium, `journalctl -b -u installer-backend.service` shows the
installation.
