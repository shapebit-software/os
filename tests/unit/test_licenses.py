"""License texts must be complete, and collection must keep upstream notices intact."""

import gzip
import importlib.machinery
import importlib.util
import io
import json
import runpy
import pathlib
import tarfile

import pytest

ROOT = pathlib.Path(__file__).parents[2]
LICENSES = ROOT / "image/rootfs/usr/share/licenses"
EXTRA_LICENSES = ROOT / "desktop/extras/licenses"


def module(name, path):
    loader = importlib.machinery.SourceFileLoader(name, str(ROOT / path))
    spec = importlib.util.spec_from_loader(name, loader)
    result = importlib.util.module_from_spec(spec)
    loader.exec_module(result)
    return result


collector = module("license_collector", "licensing/collect.py")
reader = module("license_reader", "licensing/read.py")


def archive(files):
    data = io.BytesIO()
    with tarfile.open(fileobj=data, mode="w:gz") as tar:
        for name, content in files.items():
            item = tarfile.TarInfo(name)
            item.size = len(content)
            tar.addfile(item, io.BytesIO(content))
    return data.getvalue()


def test_archive_selection_never_extracts_paths(tmp_path):
    data = archive({"../../outside": b"unwanted", "source/COPYING": b"the complete notice"})
    assert collector.member(data, "source/COPYING") == b"the complete notice"
    assert not (tmp_path / "outside").exists()
    with pytest.raises(ValueError, match="expected one"):
        collector.member(data, "*/LICENSE")


def test_ambiguous_material_requires_review():
    data = archive({"one/COPYING": b"one", "two/COPYING": b"two"})
    with pytest.raises(ValueError, match="found 2"):
        collector.member(data, "*/COPYING")


def test_notice_selection_does_not_match_a_vendored_project():
    data = archive({"project-1/LICENSES/LGPL.txt": b"project license",
                    "project-1/vendor/other/LICENSES/LGPL.txt": b"other license"})
    assert collector.member(data, "project-*/LICENSES/LGPL.txt") == b"project license"


def test_source_rpm_accepts_cpio_dot_prefix(monkeypatch):
    def command(args, **kwargs):
        if args[0] == "rpm2cpio":
            return b"cpio payload"
        if "-it" in args:
            return b"./example.spec\n./example-1.tar.gz\n"
        assert args[-1] == "./example-1.tar.gz"
        return b"source archive"
    monkeypatch.setattr(collector.subprocess, "check_output", command)
    assert collector.rpm_member(pathlib.Path("example.src.rpm"), "example-*.tar.gz") == b"source archive"


def test_rpm_notices_are_linked_without_moving_package_files(tmp_path, monkeypatch):
    upstream = tmp_path / "README.md"
    upstream.write_text("Embedded copyright and license")
    output = tmp_path / "licenses"
    monkeypatch.setattr(collector.subprocess, "check_output", lambda *a, **kw: f"example\t{upstream}\td\n")
    collector.rpm_links(output, [str(upstream)])
    link = output / "example/README.md"
    assert link.is_symlink()
    assert link.read_text() == upstream.read_text()
    assert upstream.is_file()


def test_header_preserves_copyright_terms_and_disclaimer():
    block = b"/* Copyright Holder\nPermission to use.\nNo warranty. */\nint main() {}"
    assert collector.header(block) == block.split(b"\nint")[0] + b"\n"
    lines = b"// Copyright Holder\n// Permission to use.\n// No warranty.\n\ncode"
    assert collector.header(lines) == lines.split(b"\n\n")[0] + b"\n"
    with pytest.raises(ValueError):
        collector.header(b"// unrelated header\ncode")


def test_reader_lists_shared_notices_and_reads_plain_text(tmp_path, monkeypatch):
    monkeypatch.setattr(reader, "ROOT", tmp_path)
    component = tmp_path / "example"
    component.mkdir()
    (component / "NOTICE").write_text("Copyright Example\n<verbatim text>\n")
    (component / ".hidden").write_text("{}")
    shared = tmp_path.parent / "shared-license"
    shared.write_text("Shared full license")
    (component / "LICENSE").symlink_to(shared)
    (component / "broken").symlink_to(tmp_path / "missing")
    result = reader.listing()
    assert result == [{"name": "example", "files": [
        {"name": "LICENSE", "path": "example/LICENSE"},
        {"name": "NOTICE", "path": "example/NOTICE"},
    ]}]
    assert reader.read("example/NOTICE") == "Copyright Example\n<verbatim text>\n"
    assert reader.read("example/LICENSE") == "Shared full license"
    for path in ["../secret", "/etc/passwd", "example/.hidden"]:
        with pytest.raises(ValueError):
            reader.read(path)


def test_reader_handles_compressed_legacy_notices(tmp_path, monkeypatch):
    monkeypatch.setattr(reader, "ROOT", tmp_path)
    (tmp_path / "example").mkdir()
    (tmp_path / "example/COPYING.gz").write_bytes(gzip.compress("Copyright © Example".encode("latin-1")))
    assert reader.read("example/COPYING.gz") == "Copyright © Example"


def test_each_extra_lists_committed_license_texts():
    extra = runpy.run_path(str(ROOT / "desktop/extras/extra"))
    for entry in json.loads((ROOT / "desktop/extras/extras.json").read_text()):
        assert f"{entry['id']}/NOTICE" in entry["licenses"]
        for name in entry["licenses"]:
            assert (EXTRA_LICENSES / name).read_text().strip(), name
        assert (EXTRA_LICENSES / entry["id"] / "NOTICE").read_text() == extra["notice"](entry)


def test_installed_shapebit_license_matches_the_repository():
    assert (LICENSES / "shapebit/LICENSE").read_bytes() == (ROOT / "LICENSE.md").read_bytes()

