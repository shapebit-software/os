# Development

How to work on ShapeBit: the development container, and the desktop running
in a window from this tree. Image builds and VMs run on the host
([distribution](../distribution/README.md)).

| File | What it is |
| --- | --- |
| `distrobox.ini` | The development container, `shapebit-dev`: Fedora with everything the desktop, the installer, and the unit tests need. CI installs the same packages (`.github/actions/fedora-dev`). |
| `Makefile` | `make run`: installs every feature into `build/dev/system`, as the image does, and starts `run-desktop.sh`. |
| `run-desktop.sh` | Runs the desktop in a window, with a session bus of its own. |
| `fonts.conf` | Adds the fonts the image ships (`packages/font`), which the container lacks. |
| `assistant.sh` | `make dev-assistant`: gives `make run` the assistant's model server and the speech engine. |
| `portal-tester.py` | The Portal Tester, an app that asks each portal. |

Nothing here is installed in the image.

## The container

From the repository's root, once, with the host's container engine:

```sh
DBX_CONTAINER_MANAGER=docker distrobox assemble create --file development/distrobox.ini
```

Then `make dev` enters it. Inside: `make static-checks`, `make test-unit`,
`make run`, and the installer's own commands
([packages/installer](../packages/installer/README.md#development)).

## The desktop in a window

`make run`, inside the container, needs a Wayland session and a GPU on the
host. The desktop works on the host's real devices and accounts:

- Apps lists the container's apps and the host's exported ones. The bar's
  panels change the host's volume, Wi-Fi, and Bluetooth; captures go to the
  host's Pictures and Videos. Only the power actions just log.
- The connection agent joins networks on the host's NetworkManager and BlueZ,
  but doesn't take over from the host's agents, so a network may ask the
  host's desktop for its password.
- The downloads queue runs its jobs with the host's `systemd-run --user`, so
  Welcome, Settings > Apps, and Settings > Downloads install Flatpaks into the
  host account for real, and change its default browser.
- The assistant's actions run real commands, so they change the host.
- The lock screen checks the container account's password, which distrobox
  leaves empty, so any password unlocks it; set one with `sudo passwd $USER`.

The desktop has its own session bus (`run-desktop.sh`), so apps inside reach its
notification server and portals, from this tree, not the host's. Apps offers
the **Portal Tester**; a button's name presses it at the start, as in
`development/portal-tester.py open_files`.

Welcome opens until it is finished or skipped (`welcomed` in
`~/.config/desktop/settings.json`). Settings live in `~/.config/desktop/`, the
queue's state in `~/.local/state/desktop/downloads.json`.

## The assistant and dictation

The container has neither the model server nor the speech engine. On the
host, after `make image`, `make dev-assistant` copies `llama-server` out of
the image and installs sherpa-onnx with pip, at the version the image builds,
into `build/dev`. The models are extras, as on a computer, but the person's
own here (`build/dev/extras`), so Settings > Assistant downloads them without
an administrator.

- Another model can be listed in `~/.config/assistant/models.json`, such as
  `{"id": "dev", "name": "Dev", "where": "online", "url": "http://127.0.0.1:8080/v1"}`.
- The host's desktop may keep Super for itself, as GNOME does, so here the
  **right Ctrl** key stands in for Super alone: tap to open the assistant,
  hold to speak.
- The assistant keeps keys and sign-ins in the host's keyring.
