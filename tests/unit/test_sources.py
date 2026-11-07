"""scripts/sources.py, without containers or registries."""

import hashlib
import importlib.util
import pathlib
import tarfile

import pytest

spec = importlib.util.spec_from_file_location("sources", pathlib.Path(__file__).parents[2] / "scripts" / "sources.py")
sources = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sources)


@pytest.mark.parametrize(
    "license",
    [
        "GPL-2.0-only", "LGPL-2.1-or-later", "AGPL-3.0-only", "MPL-2.0", "EPL-2.0", "CDDL-1.0",
        "GPLv2+", "MIT AND (GPL-2.0-only WITH Linux-syscall-note)", "BSD-3-Clause OR LGPL-3.0-only",
    ],
)  # fmt: skip
def test_copyleft_licenses_are_found(license):
    assert sources.copyleft([license])


@pytest.mark.parametrize("license", ["MIT", "Apache-2.0", "BSD-3-Clause AND Zlib", "OFL-1.1", "GFDL-1.3-or-later"])
def test_permissive_licenses_are_not(license):
    assert not sources.copyleft([license])


def test_a_source_counts_if_any_of_its_packages_is_copyleft():
    lines = "\n".join([
        "glibc-2.42-1.fc45.src.rpm\tLGPL-2.1-or-later",
        "fonts-1-1.fc45.src.rpm\tOFL-1.1",
        "gcc-16-1.fc45.src.rpm\tMIT",
        "gcc-16-1.fc45.src.rpm\tGPL-3.0-or-later",
        "(none)\tpubkey",
    ])  # fmt: skip
    assert sources.source_rpms(lines) == ["gcc-16-1.fc45.src.rpm", "glibc-2.42-1.fc45.src.rpm"]


def test_the_tar_is_the_same_for_the_same_files(tmp_path):
    for name in ["b-1-1.fc45.src.rpm", "a-1-1.fc45.src.rpm"]:
        (tmp_path / name).write_bytes(name.encode())
    (tmp_path / "notes.txt").write_text("not a source")
    sources.write_tar(tmp_path, tmp_path.parent / "first.tar")
    for path in tmp_path.iterdir():
        path.touch()
    sources.write_tar(tmp_path, tmp_path.parent / "second.tar")
    first, second = (tmp_path.parent / name for name in ("first.tar", "second.tar"))
    assert hashlib.sha256(first.read_bytes()).digest() == hashlib.sha256(second.read_bytes()).digest()
    with tarfile.open(first) as tar:
        assert tar.getnames() == ["a-1-1.fc45.src.rpm", "b-1-1.fc45.src.rpm"]
        assert {member.mtime for member in tar.getmembers()} == {0}


@pytest.fixture
def image(monkeypatch):
    """An image of three copyleft sources, of which the repositories have only a and b."""
    downloaded = []

    def download(image, directory, names):
        downloaded.extend(names)
        for name in names:
            if not name.startswith("c-"):
                (directory / name).write_bytes(b"downloaded")

    monkeypatch.setattr(sources, "image_source_rpms", lambda image: ["a-1.src.rpm", "b-1.src.rpm", "c-1.src.rpm"])
    monkeypatch.setattr(sources, "download", download)
    return downloaded


def test_collect_takes_the_cache_and_downloads_only_the_rest(tmp_path, image, monkeypatch):
    monkeypatch.setattr(sources, "image_source_rpms", lambda image: ["a-1.src.rpm", "b-1.src.rpm"])
    cache = tmp_path / "cache"
    cache.mkdir()
    (cache / "a-1.src.rpm").write_bytes(b"cached")
    (tmp_path / "out").mkdir()
    (tmp_path / "out/old-1.src.rpm").write_bytes(b"stale")
    sources.collect("image", tmp_path / "out", cache=cache)
    assert image == ["b-1.src.rpm"]
    assert (tmp_path / "out/a-1.src.rpm").read_bytes() == b"cached"
    assert sorted(p.name for p in (tmp_path / "out").iterdir()) == ["a-1.src.rpm", "b-1.src.rpm"]


def test_collect_fails_when_a_source_is_missing(tmp_path, image, capsys):
    with pytest.raises(SystemExit, match="c-1.src.rpm"):
        sources.collect("image", tmp_path / "out")
