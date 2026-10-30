"""scripts/report.py, on made-up data."""

import importlib.util
import pathlib

spec = importlib.util.spec_from_file_location("report", pathlib.Path(__file__).parents[2] / "scripts" / "report.py")
report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(report)

PROVENANCE = {"artifact": {"image_digest": "sha256:abc", "medium_sha256": "m"}, "source": {"commit": "c"}}


def test_package_changes_names_added_removed_and_changed():
    old = {"kernel": "1", "gone": "2", "same": "3"}
    new = {"kernel": "2", "new": "4", "same": "3"}
    assert report.package_changes(old, new) == ["gone: removed 2", "kernel: 1 -> 2", "new: added 4"]


def test_packages_reads_name_and_version():
    assert report.packages("kernel 7.2-1\nmesa 26-2\n") == {"kernel": "7.2-1", "mesa": "26-2"}


def test_report_has_commits_packages_and_identity():
    text = report.report(PROVENANCE, ["a1 Fix"], {"k": "2"}, {"k": "1"})
    assert "sha256:abc" in text and "a1 Fix" in text and "k: 1 -> 2" in text


def test_a_first_release_lists_every_package():
    assert "k: 2" in report.report(PROVENANCE, [], {"k": "2"}, None)
