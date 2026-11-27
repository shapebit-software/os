"""shapebit-system requires every feature of the OS: every package beside it,
but the installer, which is only on the medium, and the tools, which only the
development image has (image/requires.sh --tools)."""

import re
import subprocess

import pytest
from testing import package_dir

pytestmark = pytest.mark.integration

HERE = package_dir(__file__)


def test_the_system_requires_every_feature():
    tools = HERE.parents[1] / "image/requires.sh"
    if not tools.exists():
        pytest.skip("needs the repository's image/requires.sh, which names the tools")
    names = subprocess.run([tools, "--tools"], capture_output=True, text=True, check=True).stdout.split()
    features = {p.parent.name for p in HERE.parent.glob("*/*.spec")} - {"installer", "system", *names}
    required = set(re.findall(r"^Requires:\s*shapebit-(\S+) = ", (HERE / "system.spec").read_text(), re.M))
    assert required == features
