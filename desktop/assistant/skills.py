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
/usr/share/desktop/assistant/skills; the person's own in
$XDG_CONFIG_HOME/assistant/skills. One of the person's replaces the OS's of
the same name.
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
    """{name: skill}: the OS's, then the person's over them."""
    found = {}
    for directory in (VENDOR, own_dir()):
        for path in sorted(directory.glob("*.md")) if directory.is_dir() else []:
            try:
                skill = parse(path.read_text(encoding="utf-8"))
            except (OSError, UnicodeDecodeError):
                continue
            if skill:
                found[skill["name"]] = skill
    return found
