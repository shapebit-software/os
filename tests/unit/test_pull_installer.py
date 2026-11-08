"""scripts/pull-installer.sh works on a fresh checkout, where BUILD does not exist."""

import os
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).parents[2]

# Like skopeo, fail when the destination's parent is missing; record the outcome.
FAKE_SKOPEO = """#!/usr/bin/env bash
dest=${@: -1}
parent=$(dirname "${dest#oci:}")
if [[ -d $parent ]]; then echo ok >"$RECORD"; else echo "lstat $parent" >"$RECORD"; fi
exit 1
"""


def test_creates_the_build_directory(tmp_path):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    skopeo = bin_dir / "skopeo"
    skopeo.write_text(FAKE_SKOPEO)
    skopeo.chmod(0o755)
    record = tmp_path / "record"
    build = tmp_path / "build"
    env = {**os.environ, "PATH": f"{bin_dir}:{os.environ['PATH']}", "RECORD": str(record),
           "BUILD": str(build), "MEDIUM": str(build / "installer.img")}
    subprocess.run([ROOT / "scripts/pull-installer.sh", "example.org/installer:stable"],
                   env=env, capture_output=True)
    assert record.read_text().strip() == "ok"
