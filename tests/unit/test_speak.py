"""desktop/dictation/speak, with a made-up sherpa-onnx, espeak-ng, and player: what
it is given is said in order, in its language, and a stop silences it at once."""

import json
import os
import pathlib
import queue
import subprocess
import threading
import time

import pytest

pytest.importorskip("numpy")

SPEAK = pathlib.Path(__file__).parents[2] / "desktop" / "dictation" / "speak"

# A voice says each phoneme as one sample of its number, so what was played tells
# what was said; the voice notes each load.
SHERPA = """
import os, pathlib
fakes = pathlib.Path(os.environ["FAKES"])

class OfflineTtsVitsModelConfig:
    def __init__(self, model, tokens):
        self.model = model

class OfflineTtsModelConfig:
    def __init__(self, vits, num_threads):
        self.vits = vits

class OfflineTtsConfig:
    def __init__(self, model):
        self.model = model

class GenerationConfig:
    pass

class Audio:
    def __init__(self, samples):
        self.samples = samples

class OfflineTts:
    def __init__(self, config):
        with open(fakes / "loads", "a") as loads:
            loads.write(pathlib.Path(config.model.vits.model).stem + "\\n")
    def generate(self, text, config):
        with open(fakes / "phonemes", "a") as phonemes:
            phonemes.write("".join(chr(c) for line in config.phoneme_codepoints for c in line) + "\\n")
        return Audio([c / 32767 for line in config.phoneme_codepoints for c in line])
"""
# The phonemes: the voice, then the text, as one line.
ESPEAK = """#!/usr/bin/python3
import sys
voice = sys.argv[sys.argv.index("-v") + 1]
print(f"{voice}:{sys.stdin.read().strip()}")
"""
# Plays slowly, as sound does: about a second for what one sentence holds here.
PLAYER = """#!/usr/bin/python3
import os, sys, time
with open(os.environ["FAKES"] + "/played", "ab") as out:
    while data := sys.stdin.buffer.read1(64):
        out.write(data)
        out.flush()
        time.sleep(0.5)
"""


class Speaker:
    def __init__(self, tmp_path):
        self.fakes = tmp_path / "fakes"
        python = tmp_path / "python" / "sherpa_onnx"
        bin_ = tmp_path / "bin"
        voices = tmp_path / "voices"
        for folder in (self.fakes, python, bin_, voices):
            folder.mkdir(parents=True)
        (python / "__init__.py").write_text(SHERPA)
        for name, script in (("espeak-ng", ESPEAK), ("pw-play", PLAYER)):
            (bin_ / name).write_text(script)
            (bin_ / name).chmod(0o755)
        for name, espeak in (("en", "en-gb-x-rp"), ("pl", "pl")):
            (voices / f"{name}.onnx").write_bytes(b"model")
            (voices / f"{name}.onnx.json").write_text(json.dumps({
                "espeak": {"voice": espeak}, "audio": {"sample_rate": 22050}, "vowel_clusters": [["a", "ɪ"]]}))
        env = {**os.environ, "FAKES": str(self.fakes), "DICTATION_PYTHON": str(python.parent),
               "PATH": f"{bin_}:{os.environ['PATH']}"}  # fmt: skip
        self.process = subprocess.Popen([SPEAK, voices], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, env=env)
        self.lines = queue.Queue()
        threading.Thread(target=lambda: [self.lines.put(json.loads(line)) for line in self.process.stdout], daemon=True).start()

    def send(self, **message):
        self.process.stdin.write(json.dumps(message) + "\n")
        self.process.stdin.flush()

    def next(self, timeout=10):
        return self.lines.get(timeout=timeout)["state"]

    @property
    def played(self):
        path = self.fakes / "played"
        data = path.read_bytes() if path.exists() else b""
        samples = [int.from_bytes(data[i : i + 2], "little", signed=True) for i in range(0, len(data) - 1, 2)]
        return "".join(chr(s) for s in samples if s > 0)


@pytest.fixture
def speaker(tmp_path):
    started = Speaker(tmp_path)
    yield started
    started.process.kill()
    started.process.wait()


def test_sentences_are_said_in_order_each_in_its_language(speaker):
    speaker.send(say="Bateria jest pełna.")
    speaker.send(say="It is **charging** now: https://example.com")
    speaker.send(end=True)
    assert speaker.next() == "speaking"
    assert speaker.next(30) == "quiet"
    # Formatting and links are not said; each sentence in its own voice.
    assert speaker.played == "pl:Bateria jest pełna.en-gb-x-rp:It is charging now:"
    assert sorted((speaker.fakes / "loads").read_text().split()) == ["en", "pl"]


def test_a_vowel_cluster_is_said_as_the_voice_was_prepared(speaker):
    speaker.send(say="aɪ is my eye.")
    speaker.send(end=True)
    assert speaker.next() == "speaking"
    assert speaker.next(30) == "quiet"
    assert (speaker.fakes / "phonemes").read_text() == "en-gb-x-rp:\ue000 is my eye.\n"


def test_quiet_comes_only_once_everything_is_heard(speaker):
    speaker.send(say="This takes a while to say.")
    speaker.send(end=True)
    assert speaker.next() == "speaking"
    began = time.monotonic()
    assert speaker.next(30) == "quiet"
    # The player was given it at once, but plays it out first.
    assert time.monotonic() - began > 1


def test_stop_silences_it_at_once_and_drops_what_waits(speaker):
    speaker.send(say="A long sentence that is still being said.")
    speaker.send(say="Then another one.")
    assert speaker.next() == "speaking"
    began = time.monotonic()
    speaker.send(do="stop")
    assert speaker.next() == "quiet"
    assert time.monotonic() - began < 1
    played = speaker.played
    time.sleep(1.5)
    assert speaker.played == played
    assert "another" not in played
    # It speaks again after.
    speaker.send(say="Yes.")
    speaker.send(end=True)
    assert speaker.next() == "speaking"
    assert speaker.next(30) == "quiet"
