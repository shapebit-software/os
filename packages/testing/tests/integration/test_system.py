"""The system tests' plugin, on made-up tests in a pytest run of their own:
the update test's order, and what it leaves out."""

import pathlib
import textwrap

SOURCE = pathlib.Path(__file__).resolve().parents[2] / "src"
TESTS = {
    "tests/system/test_a_rollback.py": 'import pytest\npytestmark = pytest.mark.system_update(when="after")\n'
                                       "def test_rollback():\n    pass\n",
    "tests/system/test_b_services.py": "import pytest\npytestmark = pytest.mark.system_installed\n"
                                       "def test_services():\n    pass\n",
    "tests/system/test_c_reboots.py": "import pytest\npytestmark = pytest.mark.system_installed(update=False)\n"
                                      "def test_reboots():\n    pass\n",
    "tests/system/test_d_to_next.py": 'import pytest\npytestmark = pytest.mark.system_update(when="before")\n'
                                      "def test_to_next():\n    pass\n",
}


def collected(pytester, monkeypatch, *args):
    monkeypatch.setenv("PYTHONPATH", str(SOURCE))
    pytester.makeini(textwrap.dedent("""\
        [pytest]
        addopts = --import-mode=importlib -p testing.plugin -p testing.system -p no:pytest11.testinfra
          -p no:cacheprovider
        markers =
            system_installed: x
            system_image: x
            system_installer: x
            system_update: x
        """))
    for name, code in TESTS.items():
        (pytester.path / name).parent.mkdir(parents=True, exist_ok=True)
        (pytester.path / name).write_text(code)
    result = pytester.runpytest_subprocess("--collect-only", "-q", *args)
    return [line.split("::")[1] for line in result.stdout.lines if "::" in line]


def test_the_update_test_runs_its_own_around_the_installed_systems_but_the_reboots(pytester, monkeypatch):
    assert collected(pytester, monkeypatch, "--next=next.tar") == ["test_to_next", "test_services", "test_rollback"]


def test_without_an_update_every_test_keeps_its_place(pytester, monkeypatch):
    assert collected(pytester, monkeypatch, "-m", "system_installed") == ["test_services", "test_reboots"]
