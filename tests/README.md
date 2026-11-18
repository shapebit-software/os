# Testing

| Level | What it tests | Command |
| --- | --- | --- |
| Static | Lint and validate; nothing is built or run | `make static-checks` |
| Unit | Logic that needs no image or VM: `test_*.py` and `tst_*` beside the code | `make test-unit` |
| Image | The image's files; nothing boots ([content/](checks/content/)) | `make test-image` |
| 1. Scripted | The booted medium, the installed system, updates and rollback | `make test`, `make test-update` |
| 2. Full OS and UI | The medium through its UI, then using the system ([openqa/](openqa/)) | `make test-release` |
| 3. AI exploration | Reserved: an agent that explores disposable VMs; each bug it finds must become a level 1 or 2 test | |

A disk result says nothing about the installer's pages, and `make
test-release` covers less of the system's details: a release needs both. The
system checks and openQA compare the running image's digest with the recorded
one, so a result can't describe another build. Every VM attaches the medium
as a snapshot, so it stays byte for byte what `build/installer.img.json`
records. Each run leaves `build/results/<time>-<plan>/`.

## In CI

| Workflow | Starts | Does |
| --- | --- | --- |
| Verification | Every push and pull request | Static checks, then unit tests, then, when the image's inputs change, image tests with a throwaway key; each stage only if the one before passed |
| Candidate | Weekly (Monday, UTC), or by hand | Builds the image without a cache, signed with the release keys, with its sources and SBOM; installs `stable` with `os/installer:stable`, updates it to the candidate, runs level 1 and openQA's desktop modules (`FLOW=update`); if all pass, drafts the release |
| Release | By hand | Copies the candidate to `os:<version>` and `os:stable`, or undoes the last release ([release/](../release/README.md)) |
| Installer | Monthly (the 1st, UTC), or by hand | Builds the installer from `os:stable`, runs levels 1 and 2 in full (`FLOW=install`), and after approval publishes it |

So each week a new OS, tested on the path existing computers take, and each
month a new installer, from the OS that is out. An installer bug is fixed by a
Candidate and a Release, then an Installer run. Candidate's **Bootstrap**
skips the update tests while no installer exists yet.

A flaky test job can be re-run with "Re-run failed jobs": the jobs pull what
the build pushed, so the digest doesn't change. Actions artifacts hold test
results only: anyone signed in can download them, and a release-signed image
must not be public before it is released.

## Level 1: tmt

[checks/](checks/) is tmt's tree, and all that tmt copies to a guest. Its
plans, in [plans.fmf](checks/plans.fmf), are `/plans/medium` (run by `make disk`), `/plans/installed` (`make test`), and
`/plans/update` (`make test-update`). To add a check, write a `test_*`
function in a `check_*.py` of the fitting folder; a new file needs an entry
in that folder's `main.fmf`.

- **Where it runs.** The VMs, tmt, and pytest run in the development image
  ([development](../images/development/README.md)), with KVM; only the engine's work,
  such as image builds and the registry, runs on the host.
- **Machines.** [vm/test-machine.sh](vm/test-machine.sh) clones the installed
  machine for each plan (a disk overlay with copies of its EFI variables and
  TPM state), runs tmt with `provision --how connect`, and discards the
  clone. tmt's testcloud would make a new firmware and TPM, which an
  installed disk can't boot with.
- **The guest** gets only tmt's tree, with pytest and Testinfra
  ([requirements.txt](checks/requirements.txt)); nothing is installed in the system.
- **Reboots.** A test that reboots is a script that picks its stage from
  `TMT_REBOOT_COUNT` and calls `tmt-reboot`; pytest markers name the stages.
- **Updates.** `make test-update` moves a clone to `NEXT_ARCHIVE`'s build,
  checks it, then to `NEXT2_ARCHIVE`'s, and rolls back. The test moves the tag
  that the system follows through the local registry's API, so the host
  needn't act between boots.
- **The recovery key** stays on the host:
  [installed/check_recovery_key.py](checks/installed/check_recovery_key.py) passes it
  over standard input after tmt finishes.
- **After failure**, the plan's `finish` step saves the journal, failed
  units, and `bootc status`.

## Level 2: openQA

[openqa/](openqa/) is an openQA test distribution, run without a server by
isotovideo in the development image, with a network of its own (`openqa.sh`). Modules are Python; `main.pm` lists
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

