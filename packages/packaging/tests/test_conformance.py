"""conformance.py: what every package keeps to, on every package of this
repository, and on a made-up one."""

import importlib.util
import textwrap

import pytest
from testing import package_dir

pytestmark = pytest.mark.integration

HERE = package_dir(__file__)
spec = importlib.util.spec_from_file_location("conformance", HERE / "src/conformance.py")
conformance = importlib.util.module_from_spec(spec)
spec.loader.exec_module(conformance)

FEATURES = sorted(p.parent for p in HERE.parent.glob("*/*.spec"))
UNITS = [unit for feature in FEATURES for unit in conformance.units(feature)]


def name(path):
    return path.name


@pytest.mark.parametrize("feature", FEATURES, ids=name)
def test_every_package_is_named_for_its_folder(feature):
    assert conformance.name_problems(feature) == []


@pytest.mark.parametrize("feature", FEATURES, ids=name)
def test_every_package_installs_its_files_and_no_test(feature):
    assert conformance.install_problems(feature) == []


@pytest.mark.parametrize("feature", FEATURES, ids=name)
def test_every_license_names_the_licenses_of_the_installed_files(feature):
    assert conformance.license_problems(feature) == []


@pytest.mark.parametrize("feature", FEATURES, ids=name)
def test_every_package_requires_the_qml_modules_it_imports(feature):
    assert conformance.qml_problems(feature) == []


@pytest.mark.parametrize("unit", UNITS, ids=lambda u: f"{u.parents[1].name}/{u.name}")
def test_every_unit_parses(unit):
    assert conformance.unit_problems(unit) == []


def test_a_file_that_nothing_installs_and_a_wrong_name_are_found(tmp_path, monkeypatch):
    monkeypatch.setenv("PACKAGING", str(HERE / "src"))
    feature = tmp_path / "demo"
    (feature / "src").mkdir(parents=True)
    (feature / "src" / "kept").write_text("kept")
    (feature / "src" / "forgotten").write_text("forgotten")
    (feature / "demo.spec").write_text("Name: shapebit-other\nLicense: GPL-3.0-or-later\n")
    (feature / "Makefile").write_text(textwrap.dedent("""\
        include $(PACKAGING)/package.mk
        install:
        \tinstall -Dm644 -t $(share)/demo src/kept
        """))
    (tmp_path / "REUSE.toml").write_text('version = 1\n[[annotations]]\npath = "**"\nSPDX-License-Identifier = "MIT"\n')
    found = conformance.problems(feature)
    assert "demo.spec: Name is not shapebit-demo" in found
    assert "demo: not installed by its Makefile: src/forgotten" in found
    assert "demo.spec: License names GPL-3.0-or-later; its files are MIT" in found
    assert len(found) == 3


def test_an_imported_qml_module_not_required_is_found(tmp_path):
    (tmp_path / "theme" / "src" / "Theme").mkdir(parents=True)
    (tmp_path / "theme" / "src" / "Theme" / "qmldir").write_text("module Theme\n")
    (tmp_path / "panel" / "src").mkdir(parents=True)
    (tmp_path / "panel" / "src" / "Panel.qml").write_text("import QtQuick\nimport Theme\n\nItem {}\n")
    (tmp_path / "panel" / "panel.spec").write_text("Name: shapebit-panel\n")
    assert conformance.qml_problems(tmp_path / "panel") == [
        "panel.spec: imports the QML module Theme but does not require shapebit-theme"]
    (tmp_path / "panel" / "panel.spec").write_text("Name: shapebit-panel\nRequires: shapebit-theme = 1\n")
    assert conformance.qml_problems(tmp_path / "panel") == []
