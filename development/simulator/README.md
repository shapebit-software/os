# Simulator

The desktop of this tree in a window on the developer's own desktop, in
seconds and without a VM, on fake system services: for the shell and what it
shows, such as panels, Settings, and the states of the battery and the
network. Like a phone's simulator, it runs the OS's own programs, from the
development image, which has the OS's packages, but not the OS itself: no
boot, no systemd, no login. What needs those is seen in the VM
([development](../README.md)).

```sh
make simulate                        # the laptop scenario, in a window
make simulate SCENARIO=low-battery   # another scenario, from scenarios/
make watch MACHINE=simulator         # in another terminal: each save, in place
```

It is a container apart from this computer: no network, a home folder of its
own, `build/simulator/home`, which is removed to start afresh, and this
computer's display only through its Wayland socket. `make simulate` installs
the tree into it as `make sync` installs it into a machine, and `make watch`
keeps it up to date; the shell reloads in place, as its unit says
(packages/shell/system/shell.service). The compositor runs with the image's
configuration, then the session's units, those that
`graphical-session.target` wants.

| File | What it is |
| --- | --- |
| `simulate.py` | `make simulate`: the container, the tree, then the session. |
| `session.sh` | The session in the container: the buses, the fakes, the compositor, and the units. |
| `fakes.py` | The fake system services of a scenario. |
| `system-bus.conf` | The fakes' bus, in place of the system bus. |
| `scenarios/` | The scenarios, one per file, by name. |
| `templates/` | The fakes that python-dbusmock's own lack something for. |

## Scenarios

A scenario is the state of the computer that the desktop shows: a TOML file
in `scenarios/`, whose tables are [python-dbusmock](https://github.com/martinpitt/python-dbusmock)
templates, such as `upower`, `networkmanager`, and `bluez5`, each with its
`parameters` and its `calls`, the template's own methods, in order. A call's
result can be named, and a later argument `"$name"` takes it. `extends` takes
another scenario's tables, but those the file names itself:

```toml
extends = "laptop"

[upower]
calls = [
  { method = "AddDischargingBattery", args = ["BAT0", "Battery", 6.0, 600] },
]
```

A new scenario is a new file; a new service is a new table, by its template's
name. Where dbusmock's template lacks what the shell reads, such as a method
or a property of a newer version, `templates/NAME.py` takes its place: it
imports dbusmock's and adds only that, and says why.

## What it does not show

- The login screen, the lock screen's password, boot, updates, and the
  installer: no login, no systemd, no bootc.
- Sound: no PipeWire. Polkit's questions: no polkit, no logind session.
- The services that sockets or other targets start, such as the assistant.
- Real devices: brightness, cameras, and anything not faked.
