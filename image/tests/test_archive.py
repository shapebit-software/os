"""image/archive.py: an image archive's digest and labels, and a medium's record."""

import hashlib
import importlib.util
import io
import json
import pathlib
import subprocess
import tarfile

import pytest

pytestmark = pytest.mark.integration

IMAGE_DIR = pathlib.Path(__file__).parents[1]
spec = importlib.util.spec_from_file_location("archive", IMAGE_DIR / "archive.py")
archive = importlib.util.module_from_spec(spec)
spec.loader.exec_module(archive)

MANIFEST = "application/vnd.oci.image.manifest.v1+json"
INDEX = "application/vnd.oci.image.index.v1+json"


def image_archive(path, index, blobs=()):
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
    assert archive.image_digest(image_archive(tmp_path / "image.tar", index)) == "sha256:abc"


def test_image_digest_looks_inside_dockers_nested_index(tmp_path):
    outer = {"manifests": [{"digest": "sha256:outer", "mediaType": INDEX}]}
    inner = {
        "manifests": [
            {"digest": "sha256:abc", "mediaType": MANIFEST, "platform": {"architecture": "amd64"}},
            {"digest": "sha256:att", "mediaType": MANIFEST, "platform": {"architecture": "unknown"}},
        ]
    }
    path = image_archive(tmp_path / "image.tar", outer, [("blobs/sha256/outer", inner)])
    assert archive.image_digest(path) == "sha256:abc"


def test_image_digest_refuses_an_ambiguous_archive(tmp_path):
    index = {"manifests": [{"digest": "a", "mediaType": MANIFEST}, {"digest": "b", "mediaType": MANIFEST}]}
    with pytest.raises(ValueError):
        archive.image_digest(image_archive(tmp_path / "image.tar", index))


def test_sha256_is_the_files(tmp_path):
    (tmp_path / "medium").write_bytes(b"medium")
    assert archive.sha256(tmp_path / "medium") == hashlib.sha256(b"medium").hexdigest()


def labelled(tmp_path, labels):
    """An image whose config has these labels."""
    index = {"manifests": [{"digest": "sha256:man", "mediaType": MANIFEST}]}
    return image_archive(tmp_path / "image.tar", index, [
        ("blobs/sha256/man", {"config": {"digest": "sha256:cfg"}}),
        ("blobs/sha256/cfg", {"config": {"Labels": labels}}),
    ])  # fmt: skip


def test_label_reads_the_images_config(tmp_path):
    image = labelled(tmp_path, {"org.opencontainers.image.version": "202611051112"})
    assert archive.label(image, "org.opencontainers.image.version") == "202611051112"


def test_a_medium_records_its_system_and_its_own_commit(tmp_path):
    medium = tmp_path / "installer.img"
    medium.write_bytes(b"medium")
    image = labelled(tmp_path, {"org.opencontainers.image.version": "202611051112"})
    archive.write_medium_record(image, medium, "3794e90")
    assert json.loads((tmp_path / "installer.img.json").read_text()) == {
        "version": "202611051112", "image_digest": "sha256:man", "revision": "3794e90",
        "medium_sha256": hashlib.sha256(b"medium").hexdigest(),
    }  # fmt: skip


def test_the_command_line_prints_an_archives_digest(tmp_path):
    index = {"manifests": [{"digest": "sha256:abc", "mediaType": MANIFEST}]}
    image = image_archive(tmp_path / "image.tar", index)
    done = subprocess.run([IMAGE_DIR / "archive.py", "digest", image], capture_output=True, text=True)
    assert done.stdout == "sha256:abc\n"


def test_the_command_line_refuses_wrong_arguments():
    for args in [("medium", "a"), ("nothing",), ()]:
        with pytest.raises(SystemExit):
            archive.main(*args)
