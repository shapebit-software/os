"""Skills: instructions the model reads only when a request needs them, such
as how to write a longer text, so the prompt every request sends stays short.
The prompt lists each skill's name and description; the model reads one with
the use_skill action (actions.py).

A skill is a Markdown file with a header:

    ---
    name: writing
    description: When to use it, as the model's list shows it.
    temperature: 0.8
    ---
    The instructions.

temperature, if given, is what the model answers with after reading the skill
in that request; without it, the model's own (models.json).

The OS's skills are in skills/ beside this file, installed to
/usr/share/desktop/assistant/skills, and stay as they are; the person's own
are in $XDG_CONFIG_HOME/assistant/skills, NAME.md, which Settings > Assistant
adds, changes, and deletes (save, delete). A skill of the person's with the
name of one of the OS's is left out.
"""

import os
import pathlib
import re

HERE = pathlib.Path(__file__).resolve().parent
VENDOR = pathlib.Path(os.environ.get("ASSISTANT_SKILLS", HERE / "skills"))
if not VENDOR.is_dir():
    VENDOR = pathlib.Path("/usr/share/desktop/assistant/skills")
NAME = re.compile(r"[a-z0-9][a-z0-9-]{0,39}")


def own_dir():
    return pathlib.Path(os.environ.get("XDG_CONFIG_HOME") or pathlib.Path.home() / ".config") / "assistant" / "skills"


def parse(text):
    """{"name", "description", "temperature" (or None), "instructions"}, or None
    when the header is missing or wrong."""
    match = re.fullmatch(r"---\n(.*?)\n---\n(.*)", text.replace("\r\n", "\n"), re.S)
    if not match:
        return None
    header = {}
    for line in match.group(1).splitlines():
        key, _, value = line.partition(":")
        header[key.strip()] = value.strip()
    skill = {"name": header.get("name", ""), "description": header.get("description", ""),
             "temperature": None, "instructions": match.group(2).strip()}  # fmt: skip
    if not NAME.fullmatch(skill["name"]) or not skill["description"] or not skill["instructions"]:
        return None
    if "temperature" in header:
        try:
            skill["temperature"] = float(header["temperature"])
        except ValueError:
            return None
        if not 0 <= skill["temperature"] <= 2:
            return None
    return skill


def load():
    """{name: skill}, each also with "own" and its "path": the OS's, then the
    person's."""
    found = {}
    for own, directory in ((False, VENDOR), (True, own_dir())):
        for path in sorted(directory.glob("*.md")) if directory.is_dir() else []:
            try:
                skill = parse(path.read_text(encoding="utf-8"))
            except (OSError, UnicodeDecodeError):
                continue
            if skill and not (own and skill["name"] in found and not found[skill["name"]]["own"]):
                found.setdefault(skill["name"], {**skill, "own": own, "path": path})
    return found


def render(skill):
    header = [f"name: {skill['name']}", f"description: {skill['description']}"]
    if skill.get("temperature") is not None:
        header.append(f"temperature: {skill['temperature']}")
    return "---\n" + "\n".join(header) + "\n---\n" + skill["instructions"].strip() + "\n"


def save(name, description, temperature, instructions, previous=None):
    """Adds or changes one of the person's skills; previous, its name before,
    when changing one. Raises ValueError, with a message for people."""
    name = str(name).strip().casefold()
    description = " ".join(str(description).split())
    found = load()
    if not NAME.fullmatch(name):
        raise ValueError("A name is up to 40 small letters, digits, and dashes, such as meeting-notes.")
    if name in found and not found[name]["own"]:
        raise ValueError(f"{name} is a skill of the system's; choose another name.")
    if name in found and name != previous:
        raise ValueError(f"You have a skill called {name} already.")
    if temperature is not None and (isinstance(temperature, bool) or not isinstance(temperature, (int, float))):
        raise ValueError("The temperature is a number.")
    skill = parse(render({"name": name, "description": description, "temperature": temperature,
                          "instructions": str(instructions)}))  # fmt: skip
    if skill is None:
        raise ValueError("A skill needs a description, instructions, and a temperature from 0 to 2, if any.")
    directory = own_dir()
    directory.mkdir(parents=True, exist_ok=True)
    partial = directory / f".{name}.partial"
    partial.write_text(render(skill), encoding="utf-8")
    path = directory / f"{name}.md"
    os.replace(partial, path)
    # A renamed skill, or one whose file had another name, leaves no copy.
    old = found.get(previous) if previous else None
    if old and old["own"] and old["path"] != path:
        old["path"].unlink(missing_ok=True)
    return skill


def delete(name):
    skill = load().get(name)
    if not skill or not skill["own"]:
        raise ValueError(f"You have no skill called {name}.")
    skill["path"].unlink(missing_ok=True)
