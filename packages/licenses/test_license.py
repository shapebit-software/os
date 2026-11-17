"""ShapeBit's identity: its license is the repository's."""

import pathlib

ROOT = pathlib.Path(__file__).parents[2]


def test_installed_shapebit_license_matches_the_repository():
    assert (ROOT / "packages/licenses/LICENSE").read_bytes() == (ROOT / "LICENSE.md").read_bytes()
