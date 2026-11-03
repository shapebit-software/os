"""What the assistant can do on the computer: typed actions, each with what it
takes, a risk, and the commands the OS already ships; never a shell, never a
command the model writes.

Risks: "read" runs at once; "change" is reversible, and runs once the person
allowed its group, or applied it on its card; "confirm" asks on its card every
time: it is destructive, privileged, or reaches the network.

An action is prepared first: what it would do, for its card, such as which app
"firefox" is; then run. A change returns how to undo it. What the shell owns,
such as Do Not Disturb, it asks of the shell (shell/services/Assistant.qml)
through `qs ipc`.
"""

import datetime
import json
import os
import pathlib
import shutil
import subprocess
import time

HERE = pathlib.Path(__file__).resolve().parent
TREE = os.environ.get("DESKTOP_SHELL")
# The source tree's helpers in development (make run), otherwise the installed.
HELPERS = pathlib.Path(TREE).parent if TREE else pathlib.Path("/usr/libexec/desktop")
DOWNLOADS = HELPERS / "downloads" / "downloads" if TREE else HELPERS / "downloads"
APP_CATALOG = HELPERS / "apps" / "app-catalog" if TREE else HELPERS / "app-catalog"

# The groups a person allows at once, for actions that change something.
GROUPS = {
    "settings": "Change the volume, brightness, keyboard layout, and Do Not Disturb",
    "connections": "Turn Wi-Fi and Bluetooth on and off",
    "windows": "Open apps, move windows, take screenshots, and lock the screen",
}


class Failed(Exception):
    """The action couldn't be done; the message is for people and the model."""


def run(*command, timeout=20):
    try:
        done = subprocess.run(command, capture_output=True, text=True, timeout=timeout, stdin=subprocess.DEVNULL)
    except FileNotFoundError:
        raise Failed(f"{command[0]} isn't available on this computer.") from None
    except subprocess.TimeoutExpired:
        raise Failed(f"{command[0]} didn't answer in time.") from None
    if done.returncode != 0:
        raise Failed((done.stderr or done.stdout).strip().splitlines()[-1:][0] if (done.stderr or done.stdout).strip()
                     else f"{command[0]} failed.")  # fmt: skip
    return done.stdout


class Context:
    """What actions reach: the shell, which the assistant learns of when it connects."""

    def __init__(self):
        self.shell_pid = None

    def shell(self, function, *args):
        if not self.shell_pid:
            raise Failed("The desktop isn't running.")
        answer = run(os.environ.get("ASSISTANT_QS", "qs"), "ipc", "--pid", str(self.shell_pid), "call", "assistant",
                     function, *[str(a).lower() if isinstance(a, bool) else str(a) for a in args])  # fmt: skip
        return answer.strip()


class Plan:
    """A prepared action: its title for the card, and what doing it returns:
    (what the model is told, how to undo it or None)."""

    def __init__(self, title, do, detail=""):
        self.title = title
        self.detail = detail
        self.do = do


class Action:
    def __init__(self, name, description, risk, group, params, prepare):
        self.name = name
        self.description = description
        self.risk = risk
        self.group = group
        self.params = params
        self.prepare = prepare

    def schema(self):
        return {"type": "function", "function": {"name": self.name, "description": self.description, "parameters": {
            "type": "object", "properties": self.params, "required": list(self.params)}}}  # fmt: skip

    def check(self, args):
        """The arguments, as the schema says, or Failed."""
        if not isinstance(args, dict):
            raise Failed("The arguments must be an object.")
        clean = {}
        for key, spec in self.params.items():
            if key not in args:
                raise Failed(f"{key} is missing.")
            value = args[key]
            kind = spec["type"]
            if kind == "integer" and isinstance(value, float) and value.is_integer():
                value = int(value)
            if kind == "integer" and isinstance(value, str) and value.strip().lstrip("-").isdigit():
                value = int(value)
            if kind == "boolean" and isinstance(value, str) and value.lower() in ("true", "false"):
                value = value.lower() == "true"
            types = {"integer": int, "boolean": bool, "string": str}[kind]
            if not isinstance(value, types) or (kind == "integer" and isinstance(value, bool)):
                raise Failed(f"{key} must be a {kind}.")
            if "enum" in spec and value not in spec["enum"]:
                raise Failed(f"{key} must be one of {', '.join(spec['enum'])}.")
            if "minimum" in spec and value < spec["minimum"] or "maximum" in spec and value > spec["maximum"]:
                raise Failed(f"{key} must be from {spec.get('minimum')} to {spec.get('maximum')}.")
            if kind == "string" and not value.strip():
                raise Failed(f"{key} is empty.")
            clean[key] = value
        return clean


ACTIONS = {}


def action(description, risk, group=None, **params):
    def register(prepare):
        ACTIONS[prepare.__name__] = Action(prepare.__name__, description, risk, group, params, prepare)
        return prepare

    return register


PERCENT = {"type": "integer", "minimum": 0, "maximum": 100}
ON = {"type": "boolean"}


def tools():
    return [a.schema() for a in ACTIONS.values()]


# Reading.


def battery():
    for supply in sorted(pathlib.Path(os.environ.get("ASSISTANT_SYSFS", "/sys")).glob("class/power_supply/*")):
        try:
            if (supply / "type").read_text().strip() == "Battery":
                return f"{(supply / 'capacity').read_text().strip()}%, {(supply / 'status').read_text().strip().lower()}"
        except OSError:
            continue
    return "none"


def volume():
    """(level 0..100, muted) of the speakers."""
    said = run("wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@").split()
    return round(float(said[1]) * 100), "[MUTED]" in said


def brightness():
    # device,class,current,percent,max
    return int(run("brightnessctl", "--class=backlight", "--machine-readable").split(",")[3].rstrip("%"))


def wifi_on():
    return run("nmcli", "radio", "wifi").strip() == "enabled"


def bluetooth_on():
    return any(line.strip() == "Powered: yes" for line in run("bluetoothctl", "show").splitlines())


@action("Tell the date and time, battery, network, Wi-Fi, Bluetooth, volume, brightness, keyboard layout, "
        "and free disk space.", "read")  # fmt: skip
def get_status(context):
    def do():
        facts = {"time": datetime.datetime.now().astimezone().strftime("%A %d %B %Y, %H:%M %Z")}
        probes = {
            "battery": battery,
            "network": lambda: ", ".join(
                f"{kind} {name}" for kind, state, name in
                (line.split(":", 2) for line in run("nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "device").splitlines() if line.count(":") >= 2)
                if state == "connected") or "not connected",  # fmt: skip
            "wifi": lambda: "on" if wifi_on() else "off",
            "bluetooth": lambda: "on" if bluetooth_on() else "off",
            "volume": lambda: "{}%{}".format(*(lambda v: (v[0], ", muted" if v[1] else ""))(volume())),
            "brightness": lambda: f"{brightness()}%",
            "keyboard layout": lambda: context.shell("keyboardLayout"),
            "free disk space": lambda: f"{shutil.disk_usage(pathlib.Path.home()).free / 1e9:.1f} GB",
        }
        for name, probe in probes.items():
            try:
                facts[name] = probe()
            except (Failed, OSError, ValueError, IndexError):
                facts[name] = "unknown"
        return "; ".join(f"{k}: {v}" for k, v in facts.items()), None

    return Plan("Check the computer's status", do)


def application_dirs():
    home = pathlib.Path(os.environ.get("XDG_DATA_HOME") or pathlib.Path.home() / ".local/share")
    dirs = [home, home / "flatpak/exports/share"]
    dirs += [pathlib.Path(d) for d in (os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share").split(":") if d]
    dirs.append(pathlib.Path("/var/lib/flatpak/exports/share"))
    return [d / "applications" for d in dict.fromkeys(dirs)]


def desktop_entries():
    """The apps a person can open: {desktop id: {"name", "words"}}; the first of an id wins."""
    found = {}
    for directory in application_dirs():
        for path in sorted(directory.rglob("*.desktop")) if directory.is_dir() else []:
            app_id = str(path.relative_to(directory)).replace("/", "-")
            if app_id in found:
                continue
            fields, section = {}, None
            try:
                for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
                    line = line.strip()
                    if line.startswith("["):
                        section = line
                    elif section == "[Desktop Entry]" and "=" in line:
                        key, value = line.split("=", 1)
                        fields.setdefault(key.strip(), value.strip())
            except OSError:
                continue
            hidden = fields.get("NoDisplay") == "true" or fields.get("Hidden") == "true"
            found[app_id] = None if hidden or fields.get("Type") != "Application" or "Name" not in fields else {
                "name": fields["Name"],
                "words": [w.casefold() for w in [fields.get("GenericName", ""), *fields.get("Keywords", "").split(";")] if w],
            }  # fmt: skip
    return {k: v for k, v in found.items() if v}


def find_app(name):
    """The desktop id and name of the app called name, or Failed with the choices."""
    wanted = name.casefold().strip()
    entries = desktop_entries()
    ranked = []
    for app_id, entry in entries.items():
        own = entry["name"].casefold()
        score = 4 if own == wanted else 3 if own.startswith(wanted) or wanted.startswith(own) else \
            2 if wanted in own else 1 if any(wanted in w for w in entry["words"]) else 0  # fmt: skip
        if score:
            ranked.append((score, entry["name"], app_id))
    ranked.sort(reverse=True)
    if not ranked:
        names = ", ".join(sorted({e["name"] for e in entries.values()})[:40])
        raise Failed(f"No app called {name} is installed. Installed apps: {names}.")
    best = [r for r in ranked if r[0] == ranked[0][0]]
    if len(best) > 1 and ranked[0][0] < 4:
        raise Failed(f"More than one app matches {name}: {', '.join(r[1] for r in best[:8])}. Ask which one.")
    return best[0][2], best[0][1]


@action("List the installed apps.", "read")
def list_apps(context):
    return Plan("List the installed apps", lambda: (", ".join(sorted({e["name"] for e in desktop_entries().values()})), None))


@action("Search the person's files by name.", "read", query={"type": "string"})
def search_files(context, query):
    def do():
        home = pathlib.Path.home()
        wanted = query.casefold()
        found = []
        deadline = time.monotonic() + 5
        for root, dirs, files in os.walk(home):
            dirs[:] = [d for d in dirs if not d.startswith(".")]
            found += [str(pathlib.Path(root, f).relative_to(home)) for f in files if wanted in f.casefold()]
            if len(found) >= 20 or time.monotonic() > deadline:
                break
        return ("Found in the home folder: " + "; ".join(found[:20])) if found else f"No file named like {query}.", None

    return Plan(f"Search files for “{query}”", do)


# Changing settings, which can be undone.


@action("Set the display's brightness.", "change", "settings", percent=PERCENT)
def set_brightness(context, percent):
    def do():
        before = brightness()
        run("brightnessctl", "--class=backlight", "set", f"{percent}%")
        return f"Brightness is {percent}%.", lambda: run("brightnessctl", "--class=backlight", "set", f"{before}%")

    return Plan(f"Set brightness to {percent}%", do)


@action("Set the sound output volume.", "change", "settings", percent=PERCENT)
def set_volume(context, percent):
    def do():
        before, _ = volume()
        run("wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", f"{percent}%")
        return f"Volume is {percent}%.", lambda: run("wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", f"{before}%")

    return Plan(f"Set volume to {percent}%", do)


@action("Mute or unmute a sound device.", "change", "settings",
        device={"type": "string", "enum": ["speaker", "microphone"]}, muted=ON)  # fmt: skip
def set_mute(context, device, muted):
    node = "@DEFAULT_AUDIO_SINK@" if device == "speaker" else "@DEFAULT_AUDIO_SOURCE@"
    name = "the speakers" if device == "speaker" else "the microphone"

    def do():
        before = "[MUTED]" in run("wpctl", "get-volume", node)
        run("wpctl", "set-mute", node, "1" if muted else "0")
        return f"{name.capitalize()} {'muted' if muted else 'on'}.", lambda: run("wpctl", "set-mute", node, "1" if before else "0")

    return Plan(f"{'Mute' if muted else 'Unmute'} {name}", do)


@action("Turn Do Not Disturb on or off.", "change", "settings", enabled=ON)
def set_do_not_disturb(context, enabled):
    def do():
        before = context.shell("doNotDisturb") == "true"
        context.shell("setDoNotDisturb", enabled)
        return f"Do Not Disturb is {'on' if enabled else 'off'}.", lambda: context.shell("setDoNotDisturb", before)

    return Plan(f"Turn Do Not Disturb {'on' if enabled else 'off'}", do)


@action("Switch the keyboard layout.", "change", "settings", layout={"type": "string", "description": "XKB code, such as us or pl"})
def set_keyboard_layout(context, layout):
    code = layout.strip().lower()

    def do():
        before = context.shell("keyboardLayout")
        if context.shell("setKeyboardLayout", code) != "true":
            raise Failed(f"The {code} layout isn't among the keyboards in Settings > Language.")
        return f"The keyboard layout is {code}.", lambda: context.shell("setKeyboardLayout", before)

    return Plan(f"Switch the keyboard to {code}", do)


@action("Turn Wi-Fi on or off.", "change", "connections", enabled=ON)
def set_wifi(context, enabled):
    def do():
        before = wifi_on()
        run("nmcli", "radio", "wifi", "on" if enabled else "off")
        return f"Wi-Fi is {'on' if enabled else 'off'}.", lambda: run("nmcli", "radio", "wifi", "on" if before else "off")

    return Plan(f"Turn Wi-Fi {'on' if enabled else 'off'}", do)


@action("Turn Bluetooth on or off.", "change", "connections", enabled=ON)
def set_bluetooth(context, enabled):
    def do():
        before = bluetooth_on()
        run("bluetoothctl", "power", "on" if enabled else "off")
        return f"Bluetooth is {'on' if enabled else 'off'}.", lambda: run("bluetoothctl", "power", "on" if before else "off")

    return Plan(f"Turn Bluetooth {'on' if enabled else 'off'}", do)


# Apps and windows.


@action("Open an installed application.", "change", "windows", name={"type": "string"})
def open_app(context, name):
    app_id, title = find_app(name)

    def do():
        context.shell("launch", app_id)
        return f"Opened {title}.", None

    return Plan(f"Open {title}", do)


@action("Move the focused window to a workspace.", "change", "windows", workspace={"type": "integer", "minimum": 1, "maximum": 8})
def move_window_to_workspace(context, workspace):
    def do():
        if context.shell("moveWindow", workspace) != "true":
            raise Failed("No window has the focus.")
        return f"Moved the window to workspace {workspace}.", None

    return Plan(f"Move the window to workspace {workspace}", do)


@action("Take a screenshot.", "change", "windows", target={"type": "string", "enum": ["area", "window", "screen"]})
def take_screenshot(context, target):
    def do():
        context.shell("capture", target)
        return "The capture tool is open; the person takes the picture.", None

    return Plan({"area": "Capture an area", "window": "Capture the window", "screen": "Capture the screen"}[target], do)


def then(step, said):
    """An action's work that tells nothing itself: does step, and says said."""

    def do():
        step()
        return said, None

    return do


@action("Lock the screen.", "change", "windows")
def lock_screen(context):
    return Plan("Lock the screen", then(lambda: context.shell("lock"), "The screen is locked."))


# What asks every time.


@action("Shut the computer down.", "confirm")
def power_off(context):
    return Plan("Shut down", then(lambda: run("systemctl", "poweroff"), "Shutting down."),
                "Apps that are open close, and unsaved work is lost.")  # fmt: skip


@action("Restart the computer.", "confirm")
def restart(context):
    return Plan("Restart", then(lambda: run("systemctl", "reboot"), "Restarting."),
                "Apps that are open close, and unsaved work is lost.")  # fmt: skip


def catalog(*args):
    for line in run(str(APP_CATALOG), *args, timeout=120).splitlines():
        answer = json.loads(line)
        if "error" in answer:
            raise Failed(answer["error"])
        if "apps" in answer:
            return answer["apps"]
    return []


def queue(action_name, app):
    run(str(DOWNLOADS), "add", "app", action_name, app["id"], app["name"])


@action("Install an app from Flathub.", "confirm", name={"type": "string"})
def install_app(context, name):
    try:
        found = catalog("search", "--limit", "8", name)
    except Failed:
        # Flathub's list may not be downloaded yet.
        catalog("refresh")
        found = catalog("search", "--limit", "8", name)
    if not found:
        raise Failed(f"Flathub has no app called {name}.")
    app = next((a for a in found if a["name"].casefold() == name.casefold()), found[0])
    if any(a["id"] == app["id"] for a in catalog("installed")):
        raise Failed(f"{app['name']} is already installed.")

    def do():
        queue("install", app)
        return f"{app['name']} is being installed; Settings > Downloads shows how far.", None

    return Plan(f"Install {app['name']}", do, f"{app.get('summary', '')} · {app['id']}, from Flathub".lstrip(" ·"))


@action("Remove an installed app.", "confirm", name={"type": "string"})
def remove_app(context, name):
    installed = catalog("installed")
    app = next((a for a in installed if a["name"].casefold() == name.casefold()), None) or \
        next((a for a in installed if name.casefold() in a["name"].casefold()), None)  # fmt: skip
    if not app:
        raise Failed(f"No installed app is called {name}.")
    if not app.get("removable"):
        raise Failed(f"{app['name']} is part of the system, or installed for everyone, and can't be removed here.")

    def do():
        queue("remove", app)
        return f"{app['name']} is being removed.", None

    return Plan(f"Remove {app['name']}", do, "Its data stays, for if it comes back.")
