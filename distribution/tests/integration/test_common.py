"""distribution/common.py: what every step shares."""

import subprocess

import common


def test_only_what_a_workflow_reads_reaches_stdout(capfd):
    with common.stdout_to_stderr():
        print("progress")
        subprocess.run(["echo", "a command's output"], check=True)
    print("digest=sha256:abc")
    out, err = capfd.readouterr()
    assert out == "digest=sha256:abc\n"
    assert "progress" in err and "a command's output" in err


def test_the_packages_releases_are_not_the_oss():
    items = [{"tagName": "rpm-llama-server-0.8.0-1.fc45", "isLatest": True},
             {"tagName": "202611230900", "isLatest": False}, {"tagName": "202611160900", "isLatest": False}]
    assert [r["tagName"] for r in common.os_releases(items)] == ["202611230900", "202611160900"]
