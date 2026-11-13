"""desktop/dictation/dictate-engine as speech-model.service, which keeps the speech
model loaded between recordings, and --connect, through which hear reaches it; with
a made-up sherpa-onnx that writes down how many samples it heard."""

import json
import os
import pathlib
import socket
import subprocess
import time

import pytest

pytest.importorskip("numpy")

ENGINE = pathlib.Path(__file__).parents[2] / "desktop" / "dictation" / "dictate-engine"
# A second, as whole windows of Silero's 512 samples, which is what the engine takes.
SECOND = b"\1\0" * 16384

# Each load is noted; a recording's words are the count of its samples; Silero
# hears speech in loud samples only, and never cuts, so the whole recording is the
# last phrase.
SHERPA = """
import os, pathlib
fakes = pathlib.Path(os.environ["FAKES"])

class Result:
    text = ""

class Stream:
    def __init__(self):
        self.result = Result()
        self.samples = 0
    def accept_waveform(self, rate, samples):
        self.samples += len(samples)

class OfflineRecognizer:
    @staticmethod
    def from_transducer(**_):
        with open(fakes / "loads", "a") as loads:
            loads.write("load\\n")
        return OfflineRecognizer()
    def create_stream(self):
        return Stream()
    def decode_stream(self, stream):
        stream.result.text = f"{stream.samples} samples"

class _Silero:
    pass

class VadModelConfig:
    def __init__(self):
        self.silero_vad = _Silero()

class VoiceActivityDetector:
    def __init__(self, config, buffer_size_in_seconds):
        self.speech = False
    def accept_waveform(self, samples):
        self.speech = self.speech or max(samples) > 0.5
    def empty(self):
        return True
    def is_speech_detected(self):
        return self.speech
    def flush(self):
        pass
"""


class Service:
    def __init__(self, tmp_path, settings):
        self.fakes = tmp_path / "fakes"
        self.python = tmp_path / "python" / "sherpa_onnx"
        self.config = tmp_path / "config"
        for folder in (self.fakes, self.python, self.config / "desktop"):
            folder.mkdir(parents=True)
        (self.python / "__init__.py").write_text(SHERPA)
        (self.config / "desktop" / "settings.json").write_text(json.dumps(settings))
        self.socket = tmp_path / "speech-model.sock"
        own = {"FAKES": str(self.fakes), "DICTATION_PYTHON": str(self.python.parent),
               "XDG_CONFIG_HOME": str(self.config), "DICTATION_CHECK_EVERY": "0.2"}  # fmt: skip
        self.env = {**os.environ, **own}
        # As systemd passes it; only the variables named go on.
        passed = [f"--setenv={name}" for name in ("PATH", *own)]
        self.process = subprocess.Popen(
            ["systemd-socket-activate", "--listen", str(self.socket), *passed, ENGINE, "--serve", "/models"],
            env=self.env, stderr=subprocess.DEVNULL,
        )
        deadline = time.monotonic() + 10
        while not self.socket.is_socket():
            assert time.monotonic() < deadline
            time.sleep(0.05)

    def connect(self, audio):
        """One recording, as hear sends it through --connect."""
        return subprocess.run([ENGINE, "--connect", str(self.socket)], input=audio, capture_output=True,
                              env=self.env, timeout=10)  # fmt: skip

    @property
    def loads(self):
        path = self.fakes / "loads"
        return len(path.read_text().splitlines()) if path.exists() else 0


@pytest.fixture
def service(tmp_path):
    started = []

    def start(settings):
        started.append(Service(tmp_path, settings))
        return started[-1]

    yield start
    for each in started:
        each.process.kill()
        each.process.wait()


def test_the_model_loads_once_for_many_recordings(service):
    model = service({"speechModel": "used", "speechModelMinutes": 10})
    for seconds in (1, 2):
        done = model.connect(SECOND * seconds)
        assert done.returncode == 0
        assert [json.loads(line) for line in done.stdout.splitlines()] == [{"final": f"{16384 * seconds} samples"}]
    assert model.loads == 1


def test_a_phrase_begun_is_said_once_and_written_down_only_when_it_ends(service):
    # No pass over the words while the person speaks: the phrase is written down
    # once, so nothing holds up its end.
    model = service({})
    loud = b"\0\x50" * 16384
    done = model.connect(SECOND + loud + loud)
    assert [json.loads(line) for line in done.stdout.splitlines()] == [{"speech": True}, {"final": "49152 samples"}]


def test_unused_for_the_minutes_set_it_ends_and_frees_the_memory(service):
    model = service({"speechModel": "used", "speechModelMinutes": 0.02})
    assert model.connect(SECOND).returncode == 0
    # 0.02 minutes, 1.2 s, after the last recording.
    assert model.process.wait(5) == 0


def test_loaded_after_sign_in_it_stays_until_the_setting_changes(service):
    model = service({"speechModel": "ready", "speechModelMinutes": 0.01})
    # systemd-socket-activate starts it with the first connection.
    assert model.connect(SECOND).returncode == 0
    time.sleep(1.5)
    assert model.process.poll() is None
    # The setting counts at once, not only at the next start.
    (model.config / "desktop" / "settings.json").write_text(json.dumps({"speechModel": "used", "speechModelMinutes": 0.01}))
    assert model.process.wait(5) == 0


def test_a_discarded_recording_is_not_written_down_and_the_next_one_is(service):
    model = service({"speechModel": "used", "speechModelMinutes": 10})
    # hear ends the bridge, as it does to discard: the connection closes.
    caller = socket.socket(socket.AF_UNIX)
    caller.connect(str(model.socket))
    caller.sendall(SECOND)
    caller.close()
    done = model.connect(SECOND)
    assert done.returncode == 0
    assert [json.loads(line) for line in done.stdout.splitlines()] == [{"final": "16384 samples"}]
    assert model.loads == 1


def test_connect_fails_without_the_service(tmp_path):
    done = subprocess.run([ENGINE, "--connect", str(tmp_path / "none.sock")], input=SECOND, capture_output=True, timeout=10)
    assert done.returncode == 1
    assert done.stdout == b""


def test_connect_fails_when_the_service_ends_before_the_end(tmp_path):
    # Nothing written down to its end, as when the model failed: hear goes over
    # the recording again.
    path = tmp_path / "half.sock"
    listener = socket.socket(socket.AF_UNIX)
    listener.bind(str(path))
    listener.listen()
    bridge = subprocess.Popen([ENGINE, "--connect", str(path)], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    connection, _ = listener.accept()
    connection.sendall(b'{"final": "half"}\n')
    connection.close()
    out, _ = bridge.communicate(SECOND, timeout=10)
    assert bridge.returncode == 1
    assert json.loads(out) == {"final": "half"}
