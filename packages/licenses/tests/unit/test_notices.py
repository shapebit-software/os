"""notices.py: collection must keep upstream notices intact."""

import importlib.machinery
import importlib.util
import io
import pathlib
import tarfile

import pytest

ROOT = pathlib.Path(__file__).parents[4]


def module(name, path):
    loader = importlib.machinery.SourceFileLoader(name, str(ROOT / path))
    spec = importlib.util.spec_from_loader(name, loader)
    result = importlib.util.module_from_spec(spec)
    loader.exec_module(result)
    return result


collector = module("notices", "packages/licenses/tools/notices.py")


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
        assert isinstance(archive, str) or (isinstance(archive, tuple) and all(archive))
        assert to.startswith(package + "/") and ".." not in to


def test_a_notice_in_an_archive_inside_another_is_found():
    inner = archive({"data-1/license": b"the vendor's license", "data-1/README.md": b"readme"})
    outer = archive({"tool-2/data-20260512.tar.gz": inner, "tool-2/README": b"readme"})
    found = collector.nested(outer, ["tool-*/data-*.tar.gz"])
    assert collector.member(found, "data-*/license") == b"the vendor's license"


def test_committed_texts_are_whole_and_their_packages_get_notices():
    folders = list(collector.COMMITTED.iterdir())
    assert folders and all(p.is_dir() for p in folders)
    for path in collector.COMMITTED.rglob("*"):
        assert path.is_dir() or (path.parent.parent == collector.COMMITTED and path.read_text().strip())
    assert {"ca-certificates", "microcode_ctl", "shim-x64"} <= set(collector.packages())


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


def test_the_notices_package_is_under_the_licenses_of_the_packages_it_is_for():
    assert collector.licenses(["MIT", "GPL-2.0-or-later AND BSD-3-Clause", "MIT", "Zlib"]) == (
        "MIT AND (GPL-2.0-or-later AND BSD-3-Clause) AND Zlib")
