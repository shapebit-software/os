"""scripts/prune-packages.py: which versions of a package go."""

import importlib.util
import pathlib

import pytest

spec = importlib.util.spec_from_file_location(
    "prune", pathlib.Path(__file__).parents[2] / "scripts" / "prune-packages.py"
)
prune = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prune)

VERSIONS = [
    {"id": 1, "name": "sha256:new", "tags": ["stable", "202611120300"]},
    {"id": 2, "name": "sha256:new-src", "tags": ["202611120300-sources"]},
    {"id": 3, "name": "sha256:prev", "tags": ["202611051112", "candidate"]},
    {"id": 4, "name": "sha256:prev-src", "tags": ["202611051112-sources"]},
    {"id": 5, "name": "sha256:old", "tags": ["202611031907", "stable-previous"]},
    {"id": 6, "name": "sha256:loose", "tags": []},
    {"id": 7, "name": "sha256:child", "tags": []},
]
KEEP = ["stable", "202611120300", "202611120300-sources", "202611051112", "202611051112-sources"]


def test_keeps_the_tagged_versions_and_deletes_the_rest_untagged_too():
    deleted = prune.to_delete(VERSIONS, KEEP, lambda digest: [])
    assert [v["id"] for v in deleted] == [5, 6, 7]


def test_keeps_what_a_kept_index_refers_to():
    deleted = prune.to_delete(VERSIONS, KEEP, lambda digest: ["sha256:child"] if digest == "sha256:new" else [])
    assert [v["id"] for v in deleted] == [5, 6]


def test_refuses_when_a_tag_to_keep_is_missing():
    with pytest.raises(ValueError, match="202611120300-sources"):
        prune.to_delete([v for v in VERSIONS if v["id"] != 2], KEEP, lambda digest: [])
