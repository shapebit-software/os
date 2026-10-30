"""Fixtures shared by the checks. Testinfra provides `host`, here the machine the
checks run on: the image's container or the guest."""

import os
import time

import pytest


@pytest.fixture
def sh(host):
    """Run a shell command, fail with its output unless it succeeds, and return stdout."""

    def run(command, *args):
        result = host.run(command, *args)
        assert result.rc == 0, f"{result.command}\n{result.stdout}\n{result.stderr}"
        return result.stdout

    return run


@pytest.fixture
def succeeds(host):
    """Whether a shell command exits with 0."""
    return lambda command, *args: host.run(command, *args).rc == 0


@pytest.fixture
def setting():
    """A value that make gave the test run; a missing one is an error, not a skip."""

    def read(name):
        assert name in os.environ, f"{name} is not set"
        return os.environ[name]

    return read


def wait_until(predicate, timeout=30, interval=1):
    """Poll for a state that arrives on its own, such as a session starting."""
    deadline = time.monotonic() + timeout
    while True:
        value = predicate()
        if value:
            return value
        if time.monotonic() >= deadline:
            return value
        time.sleep(interval)
