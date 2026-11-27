#!/usr/bin/env python3
"""The simulator's fake system services, from a scenario (scenarios/*.toml;
README.md): each table names a python-dbusmock template, testing's fakes/NAME.py
if there is one, else dbusmock's own, which runs on the simulator's system
bus with the table's parameters, then takes its calls in order, the
template's own methods. A call's result can be named, and later arguments
"$name" take it, such as an access point's path. A scenario may extend
another, taking its tables but those it names itself.

Leaves the services running, and returns once they have taken their calls.

Usage: fakes.py SCENARIO.toml (run by session.sh)."""

import os
import pathlib
import sys
import tomllib

import dbusmock

# The fakes that the simulator and the integration tests share.
TEMPLATES = pathlib.Path(__file__).resolve().parents[2] / "packages/testing/src/testing/fakes"


def load(path):
    """PATH's scenario, over the one it extends."""
    scenario = tomllib.loads(path.read_text())
    base = scenario.pop("extends", None)
    return {**load(path.with_name(f"{base}.toml")), **scenario} if base else scenario


def resolve(value, results):
    """VALUE, with "$name" replaced by a named result, also in lists."""
    if isinstance(value, list):
        return [resolve(item, results) for item in value]
    if isinstance(value, str) and value.startswith("$"):
        return results[value[1:]]
    return value


def main():
    log = open(pathlib.Path(os.environ["XDG_RUNTIME_DIR"]) / "fakes.log", "w")
    for name, service in load(pathlib.Path(sys.argv[1])).items():
        template = TEMPLATES / f"{name}.py"
        _, mock = dbusmock.DBusTestCase.spawn_server_template(
            str(template) if template.exists() else name, service.get("parameters", {}), stdout=log, system_bus=True)
        results = {}
        for call in service.get("calls", []):
            result = getattr(mock, call["method"])(*resolve(call.get("args", []), results))
            if "name" in call:
                results[call["name"]] = result


if __name__ == "__main__":
    main()
