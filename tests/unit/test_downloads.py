"""desktop/downloads/downloads, with made-up helpers: one job at a time, each
telling how it goes, cancelled when asked, and going on after a stop."""

import fcntl
import json
import os
import pathlib
import subprocess
import time

import pytest

ROOT = pathlib.Path(__file__).parents[2]
DOWNLOADS = ROOT / "desktop" / "downloads" / "downloads"

# A helper that does what its mode file says: "ok" tells progress and ends
# well, "fail" fails, "quiet" ends saying nothing, "slow" waits a minute.
HELPER = """#!/bin/bash
echo "$*" >> "$LOG"
mode=$(cat "$MODE")
case $mode in
ok) echo '{"step": "Downloading", "percent": 40}'; echo '{"done": "x"}' ;;
fail) echo '{"error": "No room"}'; exit 1 ;;
quiet) exit 0 ;;
slow) echo $$ > "$PID"; echo '{"step": "Downloading", "percent": 10}'; exec sleep 60 ;;
esac
"""


class Queue:
    def __init__(self, tmp_path):
        self.tmp = tmp_path
        helper = tmp_path / "helper"
        helper.write_text(HELPER)
        helper.chmod(0o755)
        self.log = tmp_path / "log"
        self.mode = tmp_path / "mode"
        self.pid = tmp_path / "pid"
        self.mode.write_text("ok")
        self.state = tmp_path / "state" / "desktop" / "downloads.json"
        self.env = {**os.environ, "XDG_STATE_HOME": str(tmp_path / "state"), "DOWNLOADS_NO_WORKER": "1",
                    "LOG": str(self.log), "MODE": str(self.mode), "PID": str(self.pid),
                    **{f"DOWNLOADS_{name}": str(helper) for name in ("APP_INSTALL", "APP_REMOVE", "EXTRA")}}  # fmt: skip
        self.env.pop("DESKTOP_SHELL", None)

    def run(self, *args):
        return subprocess.run([DOWNLOADS, *args], env=self.env, check=True, timeout=30)

    def start(self, *args):
        return subprocess.Popen([DOWNLOADS, *args], env=self.env)

    def jobs(self):
        return json.loads(self.state.read_text())["jobs"]

    def job(self, key):
        return next(j for j in self.jobs() if j["key"] == key)

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []


@pytest.fixture
def queue(tmp_path):
    return Queue(tmp_path)


def wait_for(predicate):
    for _ in range(200):
        if predicate():
            return
        time.sleep(0.05)
    raise AssertionError("it did not happen")


def test_a_job_runs_its_helper_and_ends_done(queue):
    queue.run("add", "app", "install", "org.example.App", "Example")
    assert queue.job("app:org.example.App")["state"] == "queued"
    queue.run("run")
    assert queue.calls() == ["apps org.example.App"]
    job = queue.job("app:org.example.App")
    assert (job["state"], job["percent"], job["name"]) == ("done", 100, "Example")


def test_each_kind_runs_its_own_helper(queue):
    queue.run("add", "browser", "install", "firefox", "Firefox")
    queue.run("add", "extra", "install", "parakeet", "Parakeet")
    queue.run("add", "app", "remove", "org.example.App", "Example", "--delete-data")
    queue.run("add", "update", "install", "apps", "App updates")
    queue.run("run")
    assert queue.calls() == ["browser firefox", "install parakeet", "org.example.App --delete-data", "update"]


def test_a_target_has_one_job_at_a_time(queue):
    queue.run("add", "app", "install", "org.example.App", "Example")
    queue.run("add", "app", "install", "org.example.App", "Example")
    assert len(queue.jobs()) == 1
    queue.run("run")
    queue.run("add", "app", "remove", "org.example.App", "Example")
    assert [(j["action"], j["state"]) for j in queue.jobs()] == [("remove", "queued")]


def test_a_failure_keeps_the_helpers_reason(queue):
    queue.mode.write_text("fail")
    queue.run("add", "extra", "install", "parakeet", "Parakeet")
    queue.run("run")
    job = queue.job("extra:parakeet")
    assert (job["state"], job["error"]) == ("failed", "No room")


def test_a_helper_that_says_nothing_has_failed(queue):
    queue.mode.write_text("quiet")
    queue.run("add", "extra", "install", "parakeet", "Parakeet")
    queue.run("run")
    assert queue.job("extra:parakeet")["state"] == "failed"


def test_a_cancelled_job_in_the_queue_never_runs(queue):
    queue.run("add", "app", "install", "org.example.A", "A")
    queue.run("add", "app", "install", "org.example.B", "B")
    queue.run("cancel", "app:org.example.A")
    queue.run("run")
    assert queue.calls() == ["apps org.example.B"]
    assert queue.job("app:org.example.A")["state"] == "cancelled"


def test_cancelling_a_running_job_stops_its_helper(queue):
    queue.mode.write_text("slow")
    queue.run("add", "extra", "install", "parakeet", "Parakeet")
    worker = queue.start("run")
    wait_for(lambda: queue.pid.exists() and queue.pid.read_text().strip())
    wait_for(lambda: queue.job("extra:parakeet")["percent"] == 10)
    helper = int(queue.pid.read_text())
    queue.run("cancel", "extra:parakeet")
    worker.wait(timeout=10)
    assert queue.job("extra:parakeet")["state"] == "cancelled"
    assert not pathlib.Path(f"/proc/{helper}").exists()


def test_a_stopped_worker_leaves_its_job_to_the_next(queue):
    queue.mode.write_text("slow")
    queue.run("add", "extra", "install", "parakeet", "Parakeet")
    worker = queue.start("run")
    wait_for(lambda: queue.job("extra:parakeet")["state"] == "running" and queue.pid.exists())
    # As at a logout.
    worker.terminate()
    worker.wait(timeout=10)
    assert queue.job("extra:parakeet")["state"] == "running"
    queue.mode.write_text("ok")
    queue.run("run")
    assert queue.job("extra:parakeet")["state"] == "done"


def test_only_one_worker_runs(queue):
    queue.run("add", "app", "install", "org.example.App", "Example")
    queue.state.parent.mkdir(parents=True, exist_ok=True)
    with open(queue.state.parent / "worker.lock", "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        queue.run("run")
    assert queue.calls() == []
    assert queue.job("app:org.example.App")["state"] == "queued"


def test_clear_forgets_only_what_ended(queue):
    queue.run("add", "app", "install", "org.example.A", "A")
    queue.run("run")
    queue.run("add", "app", "install", "org.example.B", "B")
    queue.run("clear")
    assert [j["key"] for j in queue.jobs()] == ["app:org.example.B"]
