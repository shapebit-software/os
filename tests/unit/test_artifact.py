"""scripts/artifact.py: files as an OCI artifact, in an OCI layout."""

import hashlib
import importlib.util
import json
import pathlib

import pytest

spec = importlib.util.spec_from_file_location("artifact", pathlib.Path(__file__).parents[2] / "scripts" / "artifact.py")
artifact = importlib.util.module_from_spec(spec)
spec.loader.exec_module(artifact)


def files(tmp_path, **contents):
    directory = tmp_path / "in"
    directory.mkdir()
    for name, content in contents.items():
        (directory / name.replace("_", ".")).write_bytes(content)
    return sorted(str(path) for path in directory.iterdir())


def test_each_file_is_a_blob_named_by_its_sha256_and_titled_with_its_name(tmp_path):
    artifact.pack(tmp_path / "layout", "application/vnd.test", "Test 1", files(tmp_path, a_rpm=b"a", b_rpm=b"b"))
    manifest = artifact.manifest(tmp_path / "layout")
    assert manifest["artifactType"] == "application/vnd.test"
    assert manifest["annotations"] == {"org.opencontainers.image.title": "Test 1"}
    assert manifest["config"]["mediaType"] == "application/vnd.oci.empty.v1+json"
    assert list(artifact.files(tmp_path / "layout")) == [
        ("a.rpm", "sha256:" + hashlib.sha256(b"a").hexdigest()),
        ("b.rpm", "sha256:" + hashlib.sha256(b"b").hexdigest()),
    ]
    index = json.loads((tmp_path / "layout/index.json").read_text())
    blob = tmp_path / "layout/blobs" / index["manifests"][0]["digest"].replace(":", "/")
    assert index["manifests"][0]["size"] == blob.stat().st_size


def test_unpack_gives_back_the_files_or_only_those_named(tmp_path):
    artifact.pack(tmp_path / "layout", "application/vnd.test", "Test", files(tmp_path, a_rpm=b"a", b_rpm=b"b"))
    artifact.unpack(tmp_path / "layout", tmp_path / "all")
    assert (tmp_path / "all/a.rpm").read_bytes() == b"a" and (tmp_path / "all/b.rpm").read_bytes() == b"b"
    artifact.unpack(tmp_path / "layout", tmp_path / "one", ["b.rpm"])
    assert [p.name for p in (tmp_path / "one").iterdir()] == ["b.rpm"]
    with pytest.raises(ValueError, match="no file c.rpm"):
        artifact.unpack(tmp_path / "layout", tmp_path / "none", ["c.rpm"])


def test_a_title_cannot_leave_the_directory(tmp_path):
    artifact.pack(tmp_path / "layout", "application/vnd.test", "Test", files(tmp_path, a_rpm=b"a"))
    index = json.loads((tmp_path / "layout/index.json").read_text())
    path = tmp_path / "layout/blobs" / index["manifests"][0]["digest"].replace(":", "/")
    manifest = json.loads(path.read_text())
    manifest["layers"][0]["annotations"]["org.opencontainers.image.title"] = "../evil"
    path.write_text(json.dumps(manifest))
    with pytest.raises(ValueError, match="no usable title"):
        artifact.unpack(tmp_path / "layout", tmp_path / "out")


def test_two_files_of_one_name_are_refused(tmp_path):
    (tmp_path / "x").mkdir()
    (tmp_path / "y").mkdir()
    (tmp_path / "x/a").write_bytes(b"1")
    (tmp_path / "y/a").write_bytes(b"2")
    with pytest.raises(ValueError):
        artifact.pack(tmp_path / "layout", "t", "T", [str(tmp_path / "x/a"), str(tmp_path / "y/a")])
