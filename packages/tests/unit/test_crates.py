"""crates.py: the crates of a feature's Rust programs, from `cargo tree`'s lines."""

import importlib.machinery
import importlib.util
import pathlib

import pytest

PACKAGES = pathlib.Path(__file__).parents[2]
loader = importlib.machinery.SourceFileLoader("crates", str(PACKAGES / "crates.py"))
crates = importlib.util.module_from_spec(importlib.util.spec_from_loader("crates", loader))
loader.exec_module(crates)

TREE = """\
network v0.0.0 (/tmp/cargo/network/source)|GPL-3.0-or-later
zbus v6.3.0|MIT
serde v1.0.229|MIT OR Apache-2.0
serde v1.0.229|MIT OR Apache-2.0 (*)
serde_derive v1.0.229 (proc-macro)|MIT OR Apache-2.0
async-io v2.6.0|Apache-2.0 OR MIT
unicode-ident v1.0.27|(MIT OR Apache-2.0) AND Unicode-3.0
rustix v1.1.6|Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT
""".splitlines(keepends=True)


def test_the_crates_are_those_in_the_tree_once_without_the_feature():
    assert sorted(crates.crates(TREE)) == [("async-io", "2.6.0"), ("rustix", "1.1.6"), ("serde", "1.0.229"),
                                           ("serde_derive", "1.0.229"), ("unicode-ident", "1.0.27"),
                                           ("zbus", "6.3.0")]


def test_their_licenses_are_one_expression_with_each_term_once():
    assert crates.expression(crates.crates(TREE).values()) == (
        "(Apache-2.0 OR Apache-2.0 WITH LLVM-exception OR MIT) AND (Apache-2.0 OR MIT) AND MIT AND Unicode-3.0")


def test_install_lists_the_crates_and_copies_their_license_texts(tmp_path):
    registry = tmp_path / "registry"
    for name, files in {"zbus-6.3.0": ["LICENSE", "lib.rs"], "memchr-2.8.3": ["UNLICENSE", "COPYING", "LICENSE-MIT"]}.items():
        for file in files:
            (registry / name).mkdir(parents=True, exist_ok=True)
            (registry / name / file).write_text(file)
    found = {("zbus", "6.3.0"): "MIT", ("memchr", "2.8.3"): "Unlicense OR MIT"}
    crates.install(found, registry, tmp_path / "out")
    assert (tmp_path / "out" / "cargo-vendor.txt").read_text() == "memchr v2.8.3\nzbus v6.3.0\n"
    assert sorted(p.relative_to(tmp_path / "out").as_posix() for p in (tmp_path / "out").rglob("*") if p.is_file()) \
        == ["cargo-vendor.txt", "memchr-2.8.3/COPYING", "memchr-2.8.3/LICENSE-MIT", "memchr-2.8.3/UNLICENSE",
            "zbus-6.3.0/LICENSE"]


def test_a_crate_without_a_license_text_fails(tmp_path):
    (tmp_path / "registry" / "quiet-1.0.0").mkdir(parents=True)
    with pytest.raises(SystemExit, match="quiet 1.0.0 has no license text"):
        crates.install({("quiet", "1.0.0"): "MIT"}, tmp_path / "registry", tmp_path / "out")
