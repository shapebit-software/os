"""scripts/provenance.py, on made-up artifacts."""

import hashlib
import importlib.util
import io
import json
import pathlib
import tarfile

import pytest

spec = importlib.util.spec_from_file_location(
    "provenance", pathlib.Path(__file__).parents[2] / "scripts" / "provenance.py"
)
provenance = importlib.util.module_from_spec(spec)
spec.loader.exec_module(provenance)


MANIFEST = "application/vnd.oci.image.manifest.v1+json"
INDEX = "application/vnd.oci.image.index.v1+json"


def archive(path, index, blobs=()):
    """An OCI archive with this index.json and these blobs, named by digest."""
    with tarfile.open(path, "w") as tar:
        for name, content in [("index.json", index), *blobs]:
            data = json.dumps(content).encode()
            info = tarfile.TarInfo(name)
            info.size = len(data)
            tar.addfile(info, io.BytesIO(data))
    return path


def test_image_digest_reads_the_manifest_of_the_archive(tmp_path):
    index = {"manifests": [{"digest": "sha256:abc", "mediaType": MANIFEST}]}
    assert provenance.image_digest(archive(tmp_path / "image.tar", index)) == "sha256:abc"


def test_image_digest_looks_inside_dockers_nested_index(tmp_path):
    outer = {"manifests": [{"digest": "sha256:outer", "mediaType": INDEX}]}
    inner = {
        "manifests": [
            {"digest": "sha256:abc", "mediaType": MANIFEST, "platform": {"architecture": "amd64"}},
            {"digest": "sha256:att", "mediaType": MANIFEST, "platform": {"architecture": "unknown"}},
        ]
    }
    path = archive(tmp_path / "image.tar", outer, [("blobs/sha256/outer", inner)])
    assert provenance.image_digest(path) == "sha256:abc"


def test_image_digest_refuses_an_ambiguous_archive(tmp_path):
    index = {"manifests": [{"digest": "a", "mediaType": MANIFEST}, {"digest": "b", "mediaType": MANIFEST}]}
    with pytest.raises(ValueError):
        provenance.image_digest(archive(tmp_path / "image.tar", index))


def test_sha256_is_the_files(tmp_path):
    (tmp_path / "medium").write_bytes(b"medium")
    assert provenance.sha256(tmp_path / "medium") == hashlib.sha256(b"medium").hexdigest()


def test_a_disk_run_names_the_disk_and_what_it_came_from(tmp_path):
    disk = {"image_digest": "sha256:abc", "medium_sha256": "m", "disk_sha256": "d"}
    (tmp_path / "disk.json").write_text(json.dumps(disk))
    record = provenance.run_record(
        "system", "passed", kind="installed-disk", disk_record=tmp_path / "disk.json"
    )
    assert record["kind"] == "installed-disk"
    assert record["plan"] == "system" and record["outcome"] == "passed"
    assert record["artifact"] == disk


def test_a_kind_it_does_not_know_is_an_error():
    with pytest.raises(ValueError):
        provenance.run_record("system", "passed", kind="vm", disk_record=None)


def test_field_prints_one_value_of_a_record(tmp_path, capsys):
    record = tmp_path / "record.json"
    record.write_text(json.dumps({"image_digest": "sha256:abc"}))
    provenance.main("field", str(record), "image_digest")
    assert capsys.readouterr().out == "sha256:abc\n"
