"""The plugin, on made-up tests in a pytest run of their own."""

import textwrap

import pytest

from testing import package_dir

pytestmark = pytest.mark.integration

SOURCE = package_dir(__file__) / "src"


@pytest.fixture
def run(pytester, monkeypatch):
    """run(files, *args): a pytest run of files, {path: code}, with the plugin."""
    monkeypatch.setenv("PYTHONPATH", str(SOURCE))
    monkeypatch.delenv("CI", raising=False)

    def start(files, *args):
        pytester.makeini(textwrap.dedent("""\
            [pytest]
            addopts = --import-mode=importlib -p testing.plugin -p no:cacheprovider
            testing_unit_timeout = 0.5
            testing_integration_timeout = 2
            markers =
                integration: x
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
    result = run({"tests/test_net.py": """\
        import socket
        def test_net():
            socket.create_connection(("127.0.0.1", 9))
        """})
    result.assert_outcomes(failed=1)
    result.stdout.fnmatch_lines(["*may not open a network socket: mark it pytest.mark.integration*"])


def test_a_unit_test_may_use_a_socket_pair(run):
    run({"tests/test_pair.py": """\
        import socket
        def test_pair():
            a, b = socket.socketpair()
            a.close(), b.close()
        """}).assert_outcomes(passed=1)


def test_a_unit_test_may_not_start_a_process(run):
    result = run({"tests/test_process.py": """\
        import subprocess
        def test_process():
            subprocess.run(["true"])
        """})
    result.assert_outcomes(failed=1)
    result.stdout.fnmatch_lines(["*may not start a process*"])


def test_an_integration_test_may_do_both(run):
    run({"tests/test_process.py": """\
        import socket, subprocess
        import pytest
        pytestmark = pytest.mark.integration
        def test_process():
            subprocess.run(["true"], check=True)
            socket.socket().close()
        """}).assert_outcomes(passed=1)


def test_each_level_has_its_time(run):
    result = run({"tests/test_slow.py": """\
        import time
        import pytest
        def test_unit():
            time.sleep(1)
        @pytest.mark.integration
        def test_integration():
            time.sleep(1)
        """})
    result.assert_outcomes(passed=1, failed=1)
    result.stdout.fnmatch_lines(["*a unit test may take 0.5 s*"])


def test_unmarked_tests_are_selected_as_unit_tests(run):
    files = {"tests/topic/test_mixed.py": """\
        import pytest
        def test_unit():
            pass
        @pytest.mark.integration
        def test_integration():
            pass
        @pytest.mark.system_image
        def test_system():
            pass
        """}
    run(files, "-m", "unit").assert_outcomes(passed=1, deselected=2)
    run(files, "-m", "integration").assert_outcomes(passed=1, deselected=2)


def test_a_test_has_one_level(run):
    result = run({"tests/test_two.py": """\
        import pytest
        pytestmark = [pytest.mark.system_image, pytest.mark.integration]
        def test_two():
            pass
        """})
    assert result.ret != 0
    result.stderr.fnmatch_lines(["*test_two.py::test_two: has two levels: integration, system_image*"])


def test_in_ci_a_missing_tool_fails_instead_of_skipping(run, monkeypatch):
    files = {"tests/test_tool.py": """\
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
