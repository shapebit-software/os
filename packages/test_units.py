"""ShapeBit's packages as a whole: their units parse, and shapebit-system requires
every feature. The units' programs are in the image, not on this machine, so
only syntax counts here; the checks of the image and of the installed system
run them."""

import pathlib
import re
import subprocess

import pytest

PACKAGES = pathlib.Path(__file__).parent
UNITS = sorted(p for pattern in ("*/*.service", "*/*.timer") for p in PACKAGES.glob(pattern))
# Every feature with a spec, but the installer, which is only on the medium,
# and shapebit-system itself.
FEATURES = sorted(p.parent.name for p in PACKAGES.glob("*/*.spec") if p.parent.name not in {"installer", "system"})


@pytest.mark.parametrize("unit", UNITS, ids=lambda p: str(p.relative_to(PACKAGES)))
def test_unit_parses(unit):
    result = subprocess.run(["systemd-analyze", "verify", "--man=no", str(unit)], capture_output=True, text=True)
    problems = re.findall(r".*(?:Unknown (?:key|section)|Failed to parse|Invalid).*", result.stderr)
    assert not problems, "\n".join(problems)


def test_the_system_requires_every_feature():
    spec = (PACKAGES / "system" / "system.spec").read_text()
    required = set(re.findall(r"^Requires:\s*shapebit-(\S+) = ", spec, re.M))
    assert required == set(FEATURES)


def test_every_own_package_is_named_for_its_folder():
    for spec in PACKAGES.glob("*/*.spec"):
        assert re.search(rf"^Name:\s*shapebit-{re.escape(spec.parent.name)}$", spec.read_text(), re.M), spec
