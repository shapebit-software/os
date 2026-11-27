# Testing

How ShapeBit is tested, and the tests' own tools. Every test sits in the
`tests/` of the code it tests, which its package arranges as it likes; its
markers say its level. This package holds what the tests share, and, as its
spec's Requires, every tool they run with. Only the development image has it;
no OS image does.

## Levels

| Level | What it tests | How a test says it | Command |
| --- | --- | --- | --- |
| unit | A function or a class, in the test's own process | no marker; Rust's inline `#[cfg(test)]`; CTest's label `unit`; a QML test (`tst_*.qml`) | `make test-unit` |
| integration | A program whole, on this computer, against made-up services | `pytestmark = pytest.mark.integration`; CTest's label `integration` | `make test-integration` |
| system | The built OS on a machine: the image, the medium, the installed system, an update | one of `system_installed`, `system_image`, `system_installer`, `system_update` | `make test-system`, `test-system-image`, `test-system-installer`, `test-system-update` |
| e2e | What a person does, through the screen, from installing on (openQA) | in `tests/e2e/`, which openQA reads | `make test-e2e` |

`make test` runs the unit and integration tests, and `make check` lint and
validation too ([linting](../linting/README.md)): all that needs no image, at
every push. Every command takes `PACKAGE=`, and each run leaves
`build/results/<time>-<name>/`, with JUnit's `junit.xml`. In a package's own
folder, `make test-unit` and `make test-integration` run its tests alone.

A bug becomes a test at the first level that can catch it. A test that a level
refuses belongs at the next one.

## Layout

A package's `tests/` holds `test_*.py` (pytest), `tst_*` (Qt: CTest's, and the
QML tests that the plugin runs), `conftest.py`, `CMakeLists.txt`, and `data/`
folders, in whatever folders it likes; and `e2e/`, its openQA modules and
needles. `image/`, `distribution/`, `development/`, and `.github/` have one too.
[test_layout.py](tests/test_layout.py) fails on a test anywhere else.

## Rules

The plugin ([plugin.py](src/testing/plugin.py)), which the root
[pytest.ini](../../pytest.ini) loads, or an installed shapebit-testing by its
entry point, reads a test's level from its markers and holds it to it:

- **unit**: no network socket, no subprocess, one second a test; a test that
  needs more fails, saying to mark it `integration`. The plugin marks unit
  tests `unit`, so that `-m unit` selects them.
- **integration**: a minute a test.
- **system**: exactly one `system_*` marker, which says the machine.
- No test has two levels.
- **In CI**, a test that a `skipif` skips fails instead: a missing tool must
  not pass for a passing test.

Tests import by file, so tests of different packages may share a name.
Integration tests are Python, whatever language the program is.

| File | What it is |
| --- | --- |
| `src/testing/plugin.py` | The levels' rules, and the QML tests' runner. |
| `src/testing/fixtures.py` | What integration tests share: `serve` and `http_server`, an HTTP server on this computer; `system_bus` and `session_bus`, buses of their own for dbusmock's made-up services. `fake`, a made-up system service from `src/testing/fakes/`, which the simulator uses too. |
| `src/testing/__init__.py` | `package_dir(__file__)` and `sibling(NAME, __file__)`: how a test finds its package's files, and another's, wherever the package lives. |
| `src/testing/changed.py` | The packages that a change touches, which CI checks. |
| `src/testing/system.py` | What system tests share: `host`, Testinfra's view of the machine; `sh`, `succeeds`, `wait_until`, `setting`, `recovery_key`. |
| `src/testing/machine.py` | The machines: `make disk`, `vm`, `ssh`, `devices`, `publish`, `update-vm`, and `make sync`; the tests' own settings, such as the first owner. |
| `e2e/` | The openQA harness: `main.pm`, `lib/`, the needles that several features share, `run.py`, `new-needle.py`. |
| `testing.spec` | Its Requires are every tool the tests run with, which the development image installs. |

## System tests: pytest and Testinfra

A system test reads the machine only through `host`, never the files where
pytest runs. pytest runs in the development image
([development](../../development/README.md)), with KVM; Testinfra reaches the
machine over SSH, so nothing is copied to or installed in the system under
test. The engine, which runs the update registry, is the host's.

- **Machines.** `--machine` chooses what `host` is: `clone`, a disposable
  clone of the installed machine for each run (a disk overlay with copies of
  its EFI variables and TPM state), which an installed disk unlocks only with;
  `ssh://ADDRESS[:PORT]`, a machine that runs already; or `container://IMAGE`,
  a container of the image with no network, which Testinfra reaches through
  the engine.
- **Reboots.** A test that reboots calls `machine.reboot()`, which waits for a
  new boot; the tests after it see the machine as it came back.
- **Updates.** `make test-system-update` moves a clone to `NEXT_ARCHIVE`'s
  build ([test_to_next.py](../updates/tests/test_to_next.py), marked
  `system_update(when="before")`), runs the installed system's tests on it,
  then moves it to `NEXT2_ARCHIVE`'s and rolls back
  ([test_rollback.py](../updates/tests/test_rollback.py),
  `when="after"`). A test marked `system_installed(update=False)` stays out,
  such as the reboots that the update test does enough of. Both builds are the
  image under test as other versions
  ([update.Containerfile](../../image/update.Containerfile)), sealed again,
  which `make update-builds` makes in minutes.
- **The medium.** `make disk` runs the `system_installer` tests on the booted
  medium before it installs, and `make test-system-installer` runs only them.
- **The recovery key** stays on the host, and reaches the machine over
  standard input ([test_recovery_key.py](../boot/tests/test_recovery_key.py)).
- **After each run**, the journal, the failed units, `bootc status`, and the
  serial console are kept with the results.

A disk result says nothing about the installer's pages, and `make test-e2e`
covers less of the system's details: a release needs both. The system tests
and openQA compare the running image's digest with the recorded one, so a
result can't describe another build. Every machine attaches the medium as a
snapshot, so it stays byte for byte what `build/installer.img.json` records.

## End to end: openQA

[e2e/](e2e/) is an openQA harness, run without a server by isotovideo in the
development image, with a network of its own ([run.py](e2e/run.py)). Each
feature's modules are Python, in its `tests/e2e/`, with their needles in
`tests/e2e/needles/`; each run assembles them in one test distribution, with
`main.pm`, which lists them in the order `FLOW` chooses. Their helpers are in
`e2e/lib/`. The update flow installs with the published installer, whose
screens its own release tested: it installs through `installerctl` and waits
on state until the candidate runs, so only the tree's needles are used.

- Each module pairs what the screen shows (`assert_screen`) with the state
  beneath it (`e2e/lib/sut.py`, over SSH): a check that only looks would pass
  on a right picture of a wrong system.
- Use a needle only where the picture is what is tested. Elsewhere, wait on
  state, such as `Installer page: <name>` in the journal. When the UI changes
  on purpose, change its needle in the same commit: `e2e/new-needle.py
  FEATURE SCREENSHOT TAG ...`.
- After failure, `pool/testresults/` keeps each step's screenshot, and
  `pool/` the log and `video.webm`.

## Machines

`make disk` installs the way a person does ([machine.py](src/testing/machine.py)):
it boots the medium in QEMU with an empty disk of `DISK_SIZE`, runs the
medium's tests, and installs through `installerctl`, the command-line client
of the installer's D-Bus interface. It tests only a medium built from the
tree's commit: a published one, such as the stable medium that the update
test installs, was tested by its own release. It never builds a disk any
other way. `make installer-vm` opens the same machine in a window.

The machine's EFI variables (`build/efivars.qcow2`) and TPM state
(`build/tpm/`) belong to it, and the medium and the disk share them; `make
disk` resets them. On a new machine, the firmware starts with Microsoft's
keys, so shim's MOK manager asks to enroll the image's certificate once;
`machine.py` answers it, as a person would.

The test settings, such as the first owner and the locale that the installer
is given, are in `machine.py`, each overridable from the environment: `make
disk OWNER_NAME=someone`. The build's are in the Makefile.

**Development access.** Images and disks contain no credentials. The machines
get the SSH key in `build/ssh/` as the systemd credential
`ssh.authorized_keys.root`. `make disk` gives the installer the first owner,
`OWNER_NAME`, with the password in `build/owner-password`, `shapebit` unless
that file holds another, and the installer's settings; the recovery key goes
to `build/recovery-key`. There is no root password. `make vm` boots the disk
in a window; `make ssh` opens a shell in it.

**Updates from a local build.** `make publish` pushes the image to a registry
container of the host's engine (`machine.py publish`), which it starts unless
it runs. The machine marks it insecure, as it serves plain HTTP, and switches
to it through `10.0.2.2`:

```bash
printf '[[registry]]\nlocation = "10.0.2.2:5000"\ninsecure = true\n' \
  >/etc/containers/registries.conf.d/50-dev-registry.conf
bootc switch 10.0.2.2:5000/shapebit-os:dev
```

**Real hardware.** A medium built locally is signed with the development
keys; later updates from `stable` would need the release keys enrolled too.
Write `build/installer.img` to a USB drive of at least 8 GB with `dd`, and
install as the [guidebook](../../guidebook/Install.md) says. To run the system
tests on it, log in on a console (Ctrl+Alt+F3), connect to the network, allow
root to log in with `build/ssh/id_ed25519.pub`, and run
`make test-system GUEST=ADDRESS IMAGE_DIGEST=sha256:... OWNER_NAME=... LOCALE=... KEYBOARD_LAYOUT=... TIME_ZONE=...`.
On the medium, `journalctl -b -u installer-backend.service` shows the
installation.

## In CI

| Workflow | Starts | Does |
| --- | --- | --- |
| Verification | Every push and pull request | Lint, validation, and the unit and integration tests of the packages the change touches ([changed.py](src/testing/changed.py)), then, when the image's inputs change, the image's system tests with a throwaway key; each stage only if the one before passed |
| Candidate | Weekly (Monday, UTC), or by hand | Builds the image without a cache, signed with the release keys, with its sources and SBOM; installs `stable` with `os/installer:stable`, updates it to the candidate, runs the system tests and openQA's desktop modules (`FLOW=update`); if all pass, drafts the release |
| Release | By hand | Copies the candidate to `os:<version>`, signs it, and moves `os:stable` to it, or undoes the last release; then prunes ([distribution](../../distribution/README.md)) |
| Installer | Monthly (the 1st, UTC), or by hand | Builds the installer from `os:stable`, runs the system tests and openQA in full (`FLOW=install`), and after approval publishes it |

A change touches the packages with changed files, and those that depend on
them: whose specs require them, or whose tests read their files. Every
package's tests run with this one's plugin, so a change here touches every
package; so does a change outside `packages/`, or to what all packages share.
Candidate and Installer test every package anyway.

So each week a new OS, tested on the path existing computers take, and each
month a new installer, from the OS that is out. An installer bug is fixed by a
Candidate and a Release, then an Installer run. Candidate's **Bootstrap**
skips the update tests while no installer exists yet.

The jobs on VMs are one reusable workflow, `vm-test.yml`. A flaky test job can
be re-run with "Re-run failed jobs": the jobs pull what the build pushed, so
the digest doesn't change. Actions artifacts hold test results only: anyone
signed in can download them, and a release-signed image must not be public
before it is released.

A third level, an agent that explores disposable VMs, is reserved; each bug it
finds must become a system or e2e test.
