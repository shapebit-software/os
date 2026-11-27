"""The plugin, on made-up tests in a pytest run of their own."""

import pathlib
import textwrap

import pytest

SOURCE = pathlib.Path(__file__).resolve().parents[2] / "src"


@pytest.fixture
def run(pytester, monkeypatch):
    """run(files, layout="warn", *args): a pytest run of files, {path: code},
    with the plugin."""
    monkeypatch.setenv("PYTHONPATH", str(SOURCE))
    monkeypatch.delenv("CI", raising=False)

    def start(files, layout="warn", *args):
        pytester.makeini(textwrap.dedent(f"""\
            [pytest]
            addopts = --import-mode=importlib -p testing.plugin -p no:cacheprovider
            testing_layout = {layout}
            testing_unit_timeout = 0.5
            testing_integration_timeout = 2
            markers =
                system_installed: x
                system_image: x
                system_installer: x
                system_update: x
            """))
        for name, code in files.items():
            path = pytester.path / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(textwrap.dedent(code))
        return pytester.runpytest_subprocess(*args)

    return start


def test_a_unit_test_may_not_reach_the_network(run):
    result = run({"tests/unit/test_net.py": """\
        import socket
        def test_net():
            socket.create_connection(("127.0.0.1", 9))
        """})
    result.assert_outcomes(failed=1)
    result.stdout.fnmatch_lines(["*may not open a network socket*"])


def test_a_unit_test_may_use_a_socket_pair(run):
    run({"tests/unit/test_pair.py": """\
        import socket
        def test_pair():
            a, b = socket.socketpair()
            a.close(), b.close()
        """}).assert_outcomes(passed=1)


def test_a_unit_test_may_not_start_a_process(run):
    result = run({"tests/unit/test_process.py": """\
        import subprocess
        def test_process():
            subprocess.run(["true"])
        """})
    result.assert_outcomes(failed=1)
    result.stdout.fnmatch_lines(["*may not start a process*"])


def test_an_integration_test_may_do_both(run):
    run({"tests/integration/test_process.py": """\
        import socket, subprocess
        def test_process():
            subprocess.run(["true"], check=True)
            socket.socket().close()
        """}).assert_outcomes(passed=1)


def test_each_level_has_its_time(run):
    result = run({
        "tests/unit/test_slow.py": "import time\ndef test_slow():\n    time.sleep(1)\n",
        "tests/integration/test_slow.py": "import time\ndef test_slow():\n    time.sleep(1)\n",
    })
    result.assert_outcomes(passed=1, failed=1)
    result.stdout.fnmatch_lines(["*a unit test may take 0.5 s*"])


def test_a_system_test_has_exactly_one_machine(run):
    result = run({
        "tests/system/test_none.py": "def test_none():\n    pass\n",
        "tests/system/test_two.py": """\
            import pytest
            pytestmark = [pytest.mark.system_image, pytest.mark.system_installed]
            def test_two():
                pass
            """,
    })
    assert result.ret != 0
    result.stderr.fnmatch_lines(["*test_none.py::test_none: a system test has exactly one of*",
                                 "*test_two.py::test_two: a system test has exactly one of*"])


def test_only_a_system_test_has_a_machine(run):
    result = run({"tests/unit/test_marked.py": """\
        import pytest
        @pytest.mark.system_installed
        def test_marked():
            pass
        """})
    assert result.ret != 0
    result.stderr.fnmatch_lines(["*only a system test has system_installed*"])


def test_a_system_test_with_its_machine_runs(run):
    run({"tests/system/test_image.py": """\
        import pytest
        pytestmark = pytest.mark.system_image
        def test_image():
            pass
        """}).assert_outcomes(passed=1)


def test_a_test_outside_a_level_is_reported_and_strictly_refused(run):
    files = {"tests/test_loose.py": "def test_loose():\n    pass\n"}
    warned = run(files)
    warned.assert_outcomes(passed=1, warnings=1)
    warned.stdout.fnmatch_lines(["*not in a tests/LEVEL/ folder*"])
    refused = run(files, "strict")
    assert refused.ret != 0
    refused.stderr.fnmatch_lines(["*not in a tests/LEVEL/ folder*"])


def test_in_ci_a_missing_tool_fails_instead_of_skipping(run, monkeypatch):
    files = {"tests/integration/test_tool.py": """\
        import pytest
        @pytest.mark.skipif(True, reason="the tool is missing")
        def test_tool():
            pass
        """}
    run(files).assert_outcomes(skipped=1)
    monkeypatch.setenv("CI", "true")
    failed = run(files)
    failed.assert_outcomes(errors=1)
    failed.stdout.fnmatch_lines(["*skipped in CI*the tool is missing*"])
