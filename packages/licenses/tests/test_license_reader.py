"""Settings > Licenses must read only license texts."""

import gzip
import importlib.machinery
import importlib.util
import pathlib

import pytest

ROOT = pathlib.Path(__file__).parents[3]


def module(name, path):
    loader = importlib.machinery.SourceFileLoader(name, str(ROOT / path))
    spec = importlib.util.spec_from_loader(name, loader)
    result = importlib.util.module_from_spec(spec)
    loader.exec_module(result)
    return result


reader = module("license_reader", "packages/licenses/src/licenses")


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
