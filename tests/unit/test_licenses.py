"""License texts must be complete, collection must keep upstream notices intact,
and Settings > Licenses must read only license texts."""

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
LICENSES = ROOT / "system/usr/share/licenses"
EXTRA_LICENSES = ROOT / "desktop/extras/licenses"


def module(name, path):
    loader = importlib.machinery.SourceFileLoader(name, str(ROOT / path))
    spec = importlib.util.spec_from_loader(name, loader)
    result = importlib.util.module_from_spec(spec)
    loader.exec_module(result)
    return result


collector = module("license_notices", "image/license-notices.py")
reader = module("license_reader", "desktop/licenses/licenses")


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


def test_each_rule_names_a_package_an_archive_and_a_place():
    assert collector.RULES
    for package, archive, member, to, only_header in collector.RULES:
        assert archive and member.count("/") >= 1 and isinstance(only_header, bool)
        assert to.startswith(package + "/") and ".." not in to


def test_header_preserves_copyright_terms_and_disclaimer():
    block = b"/* Copyright Holder\nPermission to use.\nNo warranty. */\nint main() {}"
    assert collector.header(block) == block.split(b"\nint")[0] + b"\n"
    lines = b"// Copyright Holder\n// Permission to use.\n// No warranty.\n\ncode"
    assert collector.header(lines) == lines.split(b"\n\n")[0] + b"\n"
    with pytest.raises(ValueError):
        collector.header(b"// unrelated header\ncode")


def test_header_skips_a_description_before_the_notice():
    # libdrm's xf86drm.c: a description, then the MIT notice.
    notice = b"/*\n * Copyright 1999 Precision Insight\n * Permission is hereby granted\n */"
    source = b"/**\n * \\file xf86drm.c\n */\n\n" + notice + b"\n\n#include <stdio.h>\n/* Copyright later */"
    assert collector.header(source) == notice + b"\n"


def test_header_takes_a_notice_that_names_its_license():
    # libatasmart: an LGPL notice, without the word "permission".
    notice = (b"/***\n    Copyright 2008 Lennart Poettering\n    libatasmart is free software; under the terms of"
              b" the GNU Lesser General Public License\n***/")
    assert collector.header(b"/*-*- Mode: C -*-*/\n\n" + notice + b"\nint x;") == notice + b"\n"


def test_reader_lists_shared_notices_and_reads_plain_text(tmp_path, monkeypatch):
    monkeypatch.setattr(reader, "ROOT", tmp_path)
    monkeypatch.setattr(reader, "FROM_RPMS", False)
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
    for path in ["../secret", "/etc/passwd", "example/.hidden", "example/broken"]:
        with pytest.raises(ValueError):
            reader.read(path)


def test_reader_finds_the_texts_rpms_keep_elsewhere(tmp_path, monkeypatch):
    licenses, share = tmp_path / "licenses", tmp_path / "share"
    (licenses / "pip").mkdir(parents=True)
    (licenses / "pip/COPYING").write_text("in the licenses folder")
    share.mkdir()
    files = {"site-packages/pip/LICENSE.txt": "pip's license", "share/doc/libX/COPYING": "X license",
             "share/doc/libX/README": "not a license", "share/doc/glvnd/README.md": "glvnd license",
             "share/doc/libX/empty-LICENSE": ""}
    for name, text in files.items():
        (tmp_path / name).parent.mkdir(parents=True, exist_ok=True)
        (tmp_path / name).write_text(text)
    lines = "\n".join([
        f"pip\t{tmp_path}/site-packages/pip/LICENSE.txt\tl",
        f"libX\t{tmp_path}/share/doc/libX/COPYING\td",
        f"libX\t{tmp_path}/share/doc/libX/README\td",
        f"libX\t{tmp_path}/share/doc/libX/empty-LICENSE\tl",
        f"glvnd\t{tmp_path}/share/doc/glvnd/README.md\td",
        "pip\t/usr/share/licenses/pip/COPYING\tl",
    ])
    # This test's share/ stands in for /usr/share/, where texts count by their name.
    monkeypatch.setattr(reader, "SHARE", f"{tmp_path}/share/")
    monkeypatch.setattr(reader, "DOCUMENTS", {f"{tmp_path}/share/doc/glvnd/README.md"})
    assert reader.rpm_texts(lines) == {"pip": [tmp_path / "site-packages/pip/LICENSE.txt"],
                                       "libX": [tmp_path / "share/doc/libX/COPYING"],
                                       "glvnd": [tmp_path / "share/doc/glvnd/README.md"]}
    monkeypatch.setattr(reader, "ROOT", licenses)
    monkeypatch.setattr(reader, "FROM_RPMS", True)
    monkeypatch.setattr(reader.subprocess, "run", lambda *a, **kw: type("R", (), {"stdout": lines})())
    assert {f["path"] for c in reader.listing() for f in c["files"]} == {
        "pip/COPYING", "pip/LICENSE.txt", "libX/COPYING", "glvnd/README.md"}
    assert reader.read("pip/LICENSE.txt") == "pip's license"


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

