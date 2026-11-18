# Development

How to work on ShapeBit: one development image with every tool, which lint,
validate, the unit tests, every feature's development (the desktop in a
window among them), and the VMs and checks of the built OS use. Only the
container engine's work, such as building the OS image, runs on the host
([distribution](../distribution/README.md)).

| File | What it is |
| --- | --- |
| `Containerfile` | The development image: the image's Fedora with everything the checks, the installer, and the desktop need. CI uses it too. |
| `dev.sh` | Runs a command in the image as the developer, in this repository, with KVM; with `--desktop`, with the host session's display, buses, and GPU. |
| `run-desktop.sh` | `make run`, in the image: the desktop in a window, with a session bus of its own. |
| `flatpak` | The image's `flatpak`: the host's, through the host's user manager. |

Nothing here is installed in the image.

## Getting started

A computer needs KVM, Git, Make, OpenSSL, and Docker or Podman; nothing else
is installed on it. From the repository's root:

```sh
make test-unit ENGINE=docker   # or podman: the engine is ENGINE's, without sudo
```

`make` builds the image the first time and whenever `Containerfile` changes,
then runs the target in it. So do `make lint`, `make validate`,
`make static-checks`, and `make run`, and the VMs and checks of the built OS,
such as `make disk`, `make vm`, `make ssh`, and `make test`, around the
engine's builds; `make dev` opens a shell there, for the
installer's own commands ([packages/installer](../packages/installer/README.md#development)).
In the image, `make` runs targets as they are.

Editors that open dev containers, such as VS Code and JetBrains, and GitHub
Codespaces open the same image (`.devcontainer/`).

## The desktop in a window

`make run` needs a Wayland session and a GPU on the host. The desktop works
on the host's real devices and accounts:

- Apps lists the image's apps and the host's Flatpaks, which open in the
  desktop. The bar's panels change the host's volume, Wi-Fi, and Bluetooth;
  captures go to the host's Pictures and Videos. Only the power actions just
  log.
- The connection agent joins networks on the host's NetworkManager and BlueZ,
  but doesn't take over from the host's agents, so a network may ask the
  host's desktop for its password.
- The downloads queue runs its jobs with the host's `systemd-run --user`, so
  Welcome, Settings > Apps, and Settings > Downloads install Flatpaks into the
  host account for real, and change its default browser.
- The assistant's actions run real commands, so they change the host.
- The lock screen unlocks with any password.

The desktop has its own session bus (`run-desktop.sh`), so apps inside reach its
notification server and portals, from this tree, not the host's. To try each
portal, install [ASHPD Demo](https://flathub.org/apps/com.belmoussaoui.ashpd.demo)
from Settings > Apps, or with `flatpak install --user flathub
com.belmoussaoui.ashpd.demo`; as a Flatpak, it asks as other apps do, and the
desktop asks the person for permissions and background activity.

Welcome opens until it is finished or skipped (`welcomed` in
`~/.config/desktop/settings.json`). Settings live in `~/.config/desktop/`, the
queue's state in `~/.local/state/desktop/downloads.json`.

## The assistant and dictation

The model server and the speech engine are the image's own packages. Build
them once; `make run` then installs them into its system, `build/dev/system`:

```sh
make rpm RPM=packages/assistant/llama-server
make rpm RPM=packages/dictation/sherpa-onnx
```

The models are extras, as on a computer, but the person's own here
(`build/dev/extras`), so Settings > Assistant downloads them without an
administrator.

- Another model can be listed in `~/.config/assistant/models.json`, such as
  `{"id": "dev", "name": "Dev", "where": "online", "url": "http://127.0.0.1:8080/v1"}`.
- The host's desktop may keep Super for itself, as GNOME does, so here the
  **right Ctrl** key stands in for Super alone: tap to open the assistant,
  hold to speak.
- The assistant keeps keys and sign-ins in the host's keyring.
