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


# Smart Turn's runtime: the features must be Whisper's, 80 by 800; how likely the
# person is done follows the loudest feature, so loud and quiet differ.
ONNXRUNTIME = """
import os, pathlib
import numpy
fakes = pathlib.Path(os.environ["FAKES"])

class SessionOptions:
    pass

class InferenceSession:
    def __init__(self, path, options=None, providers=None):
        with open(fakes / "turn-loads", "a") as loads:
            loads.write(path + "\\n")
    def run(self, outputs, inputs):
        features = inputs["input_features"]
        assert features.shape == (1, 80, 800), features.shape
        return [1 / (1 + numpy.exp(-features.max().reshape(1, 1)))]
"""


class Service:
    def __init__(self, tmp_path, settings, turn=False):
        self.fakes = tmp_path / "fakes"
        self.python = tmp_path / "python" / "sherpa_onnx"
        self.config = tmp_path / "config"
        for folder in (self.fakes, self.python, self.config / "desktop"):
            folder.mkdir(parents=True)
        (self.python / "__init__.py").write_text(SHERPA)
        (self.python.parent / "onnxruntime").mkdir()
        (self.python.parent / "onnxruntime" / "__init__.py").write_text(ONNXRUNTIME)
        self.models = tmp_path / "models"
        self.models.mkdir()
        if turn:
            (self.models / "smart-turn.onnx").write_bytes(b"model")
        (self.config / "desktop" / "settings.json").write_text(json.dumps(settings))
        self.socket = tmp_path / "speech-model.sock"
        own = {"FAKES": str(self.fakes), "DICTATION_PYTHON": str(self.python.parent),
               "XDG_CONFIG_HOME": str(self.config), "DICTATION_CHECK_EVERY": "0.2"}  # fmt: skip
        self.env = {**os.environ, **own}
        # As systemd passes it; only the variables named go on.
        passed = [f"--setenv={name}" for name in ("PATH", *own)]
        self.process = subprocess.Popen(
            ["systemd-socket-activate", "--listen", str(self.socket), *passed, ENGINE, "--serve", str(self.models)],
            env=self.env, stderr=subprocess.DEVNULL,
        )
        deadline = time.monotonic() + 10
        while not self.socket.is_socket():
            assert time.monotonic() < deadline
            time.sleep(0.05)

    def connect(self, audio, *more):
        """One recording, as hear sends it through --connect."""
        return subprocess.run([ENGINE, "--connect", str(self.socket), *more], input=audio, capture_output=True,
                              env=self.env, timeout=10)  # fmt: skip

    @property
    def loads(self):
        path = self.fakes / "loads"
        return len(path.read_text().splitlines()) if path.exists() else 0


@pytest.fixture
def service(tmp_path):
    started = []

    def start(settings, turn=False):
        started.append(Service(tmp_path, settings, turn))
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


def test_with_smart_turn_each_phrase_says_how_likely_the_person_is_done(service):
    model = service({}, turn=True)
    done = model.connect(SECOND)
    said = [json.loads(line) for line in done.stdout.splitlines()]
    assert len(said) == 1 and said[0]["final"] == "16384 samples"
    assert 0 < said[0]["turn"] < 1
    # Loaded with the service, once.
    model.connect(SECOND)
    assert len((model.fakes / "turn-loads").read_text().splitlines()) == 1


def test_without_smart_turn_phrases_come_unjudged(service):
    model = service({})
    said = [json.loads(line) for line in model.connect(SECOND).stdout.splitlines()]
    assert said == [{"final": "16384 samples"}]


def test_smart_turn_hears_the_features_whisper_makes():
    # Against transformers' WhisperFeatureExtractor(chunk_length=8), as Smart
    # Turn's own code uses it, for 1.5 s of two tones: the same numbers.
    import importlib.machinery
    import importlib.util

    import numpy

    loader = importlib.machinery.SourceFileLoader("engine", str(ENGINE))
    spec = importlib.util.spec_from_loader("engine", loader)
    engine = importlib.util.module_from_spec(spec)
    loader.exec_module(engine)
    t = numpy.arange(int(16000 * 1.5)) / 16000
    tones = (0.5 * numpy.sin(2 * numpy.pi * 440 * t) + 0.2 * numpy.sin(2 * numpy.pi * 2500 * t)).astype(numpy.float32)
    got = engine.turn_features(tones, engine.mel_filters())
    assert got.shape == (1, 80, 800)
    expected = {(0, 0): 1.20636, (10, 5): 1.5584, (40, 50): -0.35214, (79, 99): -0.35214, (20, 400): -0.35214}
    assert {k: round(float(got[0, k[0], k[1]]), 5) for k in expected} == expected
    assert round(float(got.mean()), 5) == -0.31416


def test_a_whole_recording_is_written_down_in_pieces_of_up_to_15_seconds(service):
    # As dictation's at its stop: nothing goes out while it comes, nor as it
    # begins; then pieces, here with no pause in it, cut at 15 s.
    model = service({}, turn=True)
    loud = b"\0\x50" * 16000
    done = model.connect(loud * 20, "--recorded")
    assert done.returncode == 0
    said = [json.loads(line) for line in done.stdout.splitlines()]
    assert said == [{"final": f"{15 * 16000} samples"}, {"final": f"{5 * 16000} samples"}]


def test_a_connection_without_its_line_writes_nothing_down(service):
    model = service({})
    caller = socket.socket(socket.AF_UNIX)
    caller.connect(str(model.socket))
    caller.sendall(b"not json\n" + SECOND)
    caller.shutdown(socket.SHUT_WR)
    # Closed, with nothing said: plainly, or reset, as what was sent goes unread.
    try:
        assert caller.recv(100) == b""
    except ConnectionResetError:
        pass
    # The next one is heard as ever.
    assert model.connect(SECOND).returncode == 0


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
    caller.sendall(b'{"recorded": false}\n' + SECOND)
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
