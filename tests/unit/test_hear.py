"""desktop/dictation/hear, with a made-up recorder, engine, and player. Every path
ends with the words, or with nothing, and leaves no audio behind."""

import importlib.machinery
import importlib.util
import json
import os
import pathlib
import queue
import signal
import struct
import subprocess
import threading
import time

import pytest

HEAR = pathlib.Path(__file__).parents[2] / "desktop" / "dictation" / "hear"

LOUD = struct.pack("<h", 20000) * 800
QUIET_SOUND = b"\0" * 1600
RECORDER = """#!/usr/bin/python3
import os, signal, sys, time
signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
open(os.environ["FAKES"] + "/recording", "w").close()
while True:
    sys.stdout.buffer.write(open(os.environ["FAKES"] + "/sound", "rb").read())
    sys.stdout.buffer.flush()
    time.sleep(0.05)
"""
RECORDER_FAILS = "#!/bin/bash\nexit 1\n"
# As the real one (dictation/dictate-engine): reads the audio to its end, then says
# each line of "said" as a phrase. Files in FAKES make it say a draft first
# ("engine-draft"), wait for "go" ("engine-waits"), or hang or fail for that many
# runs ("engine-hangs", "engine-fails").
ENGINE = """#!/usr/bin/python3
import json, os, pathlib, sys, time
fakes = pathlib.Path(os.environ["FAKES"])
def mark(name, default=""):
    path = fakes / name
    return path.read_text() if path.exists() else default
with open(fakes / "engine-runs", "a") as runs:
    runs.write(" ".join(sys.argv[1:]) + "\\n")
run = len(mark("engine-runs").splitlines())
sys.stdout.write(mark("engine-draft"))
sys.stdout.flush()
(fakes / "engine-audio").write_bytes(sys.stdin.buffer.read())
(fakes / "engine-writing").touch()
if run <= int(mark("engine-hangs", "0")):
    time.sleep(60)
while (fakes / "engine-waits").exists() and not (fakes / "go").exists():
    time.sleep(0.02)
if run <= int(mark("engine-fails", "0")):
    sys.exit(1)
for line in mark("said").splitlines():
    if line.strip():
        print(json.dumps({"final": line}), flush=True)
"""
# Live, as the real one is while the person speaks: each line added to "phrases"
# comes out as a phrase at once; it ends when the audio does.
LIVE_ENGINE = """#!/usr/bin/python3
import json, os, pathlib, sys, threading, time
fakes = pathlib.Path(os.environ["FAKES"])
ended = threading.Event()
def drain():
    while sys.stdin.buffer.read(65536):
        pass
    ended.set()
threading.Thread(target=drain, daemon=True).start()
told = 0
while True:
    path = fakes / "phrases"
    lines = path.read_text().splitlines() if path.exists() else []
    for line in lines[told:]:
        print(json.dumps({"final": line}), flush=True)
    # Rewriting the file empties it for a moment: only ever go on.
    told = max(told, len(lines))
    if ended.is_set():
        break
    time.sleep(0.02)
"""
PLAYER = '#!/bin/bash\necho "$1" >>"$FAKES/played"\n'
VOICE_MODE = {"DICTATION_TURN_PAUSE": "0.3", "DICTATION_CONVERSE_QUIET": "1.5"}


class Hearing:
    def __init__(self, tmp_path, *args, recorder=RECORDER, said="", sound=LOUD, env=None, draft=None, waits=False,
                 hangs=0, fails=0, parakeet=True, engine=ENGINE):  # fmt: skip
        self.fakes = tmp_path / "fakes"
        self.runtime = tmp_path / "runtime"
        self.fakes.mkdir()
        self.runtime.mkdir()
        (self.fakes / "said").write_text(said)
        (self.fakes / "sound").write_bytes(sound)
        if draft:
            (self.fakes / "engine-draft").write_text(json.dumps(draft) + "\n")
        if waits:
            (self.fakes / "engine-waits").touch()
        (self.fakes / "engine-hangs").write_text(str(hangs))
        (self.fakes / "engine-fails").write_text(str(fails))
        for name, script in (("pw-record", recorder), ("dictate-engine", engine), ("pw-play", PLAYER)):
            path = self.fakes / name
            path.write_text(script)
            path.chmod(0o755)
        self.process = subprocess.Popen(
            [HEAR, *args],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            text=True,
            env={
                **os.environ,
                "PATH": f"{self.fakes}:{os.environ['PATH']}",
                "FAKES": str(self.fakes),
                "XDG_RUNTIME_DIR": str(self.runtime),
                "DICTATION_ENGINE": str(self.fakes / "dictate-engine"),
                "DICTATION_PARAKEET": str(self.fakes) if parakeet else "/nonexistent",
                "DICTATION_ENGINE_WAIT": "1",
                **(env or {}),
            },
        )
        self.lines = queue.Queue()
        self.heard = []
        threading.Thread(target=self.read, daemon=True).start()

    def read(self):
        for line in self.process.stdout:
            self.lines.put(json.loads(line))

    def do(self, what):
        self.process.stdin.write(json.dumps({"do": what}) + "\n")
        self.process.stdin.flush()

    def wait_for(self, state, **matching):
        deadline = time.monotonic() + 10
        while True:
            try:
                message = self.lines.get(timeout=max(0, deadline - time.monotonic()))
            except queue.Empty:
                raise AssertionError(f"no {state} {matching}; heard {self.heard[-5:]}") from None
            self.heard.append(message)
            if message["state"] == state and all(message.get(k) == v for k, v in matching.items()):
                return message

    def wait_for_file(self, name):
        deadline = time.monotonic() + 10
        while not (self.fakes / name).exists():
            assert time.monotonic() < deadline, f"{name} did not appear"
            time.sleep(0.02)

    def recording(self):
        self.wait_for_file("recording")
        self.wait_for("listening")

    def say(self):
        self.recording()
        self.do("stop")

    def ended(self):
        return self.process.wait(10)

    def file(self, name):
        path = self.fakes / name
        return path.read_text() if path.exists() else None

    @property
    def left_behind(self):
        return list(self.runtime.iterdir())


@pytest.fixture
def hear(tmp_path):
    started = []

    def start(*args, **kwargs):
        started.append(Hearing(tmp_path, *args, **kwargs))
        return started[-1]

    yield start
    for hearing in started:
        hearing.process.kill()
        hearing.process.wait()


# The words ----------------------------------------------------------------------


def test_the_words_come_back_as_one_text(hear):
    hearing = hear(said=" Dzień dobry,\n wszystkim.\n")
    hearing.say()
    assert hearing.wait_for("writing")
    assert hearing.wait_for("done")["text"] == "Dzień dobry, wszystkim."
    assert hearing.ended() == 0
    assert hearing.left_behind == []


def test_control_characters_never_pass(hear):
    hearing = hear(said="safe\x1b[31m text\x07\n")
    hearing.say()
    assert all(c.isprintable() for c in hearing.wait_for("done")["text"])


def test_the_engine_hears_the_recording_with_the_models(hear):
    hearing = hear(said="Tak.\n")
    hearing.say()
    hearing.wait_for("done")
    assert hearing.file("engine-runs") == f"{hearing.fakes}\n"
    assert (hearing.fakes / "engine-audio").read_bytes().startswith(LOUD)


def test_the_draft_is_said_while_listening(hear):
    hearing = hear(said="Dzień dobry.\n", draft={"draft": "Dzień", "tail": "dobry"})
    message = hearing.wait_for("draft")
    assert (message["text"], message["tail"]) == ("Dzień", "dobry")


def test_words_agree_ignoring_case_and_punctuation():
    loader = importlib.machinery.SourceFileLoader("engine", str(HEAR.with_name("dictate-engine")))
    spec = importlib.util.spec_from_loader("engine", loader)
    engine = importlib.util.module_from_spec(spec)
    loader.exec_module(engine)
    assert engine.agreed(["Ask", "not,", "what"], ["ask", "not", "when", "what"]) == 2
    assert engine.agreed([], ["ask"]) == 0


def test_without_parakeet_it_fails_before_it_listens(hear):
    hearing = hear(parakeet=False)
    assert hearing.wait_for("failed")
    assert hearing.ended() == 1
    assert hearing.file("recording") is None, "no microphone for this"
    assert hearing.left_behind == []


# Silence ------------------------------------------------------------------------


def test_the_level_follows_the_sound(hear):
    hearing = hear()
    hearing.recording()
    assert hearing.wait_for("listening", quiet=False, idle=False, level=1)


def test_a_microphone_that_hears_nothing_says_so(hear):
    hearing = hear(sound=QUIET_SOUND, env={"DICTATION_QUIET": "0.2"})
    hearing.recording()
    assert hearing.wait_for("listening", quiet=True)["level"] == 0


def test_a_long_silence_after_speech_asks_then_stops_with_the_words(hear):
    hearing = hear(said="Hello\n", env={"DICTATION_IDLE": "0.2", "DICTATION_GIVE_UP": "0.8"})
    hearing.recording()
    hearing.wait_for("listening", idle=False, quiet=False)
    (hearing.fakes / "sound").write_bytes(QUIET_SOUND)
    hearing.wait_for("listening", idle=True, quiet=False)
    hearing.wait_for("writing")
    assert hearing.wait_for("done")["text"] == "Hello"


def test_giving_up_on_silence_stops_listening(hear):
    hearing = hear(sound=QUIET_SOUND, env={"DICTATION_GIVE_UP": "0.3"})
    hearing.recording()
    hearing.wait_for("writing")
    hearing.wait_for("nothing")
    assert hearing.ended() == 0


def test_silence_gets_no_text_as_a_model_may_invent_words(hear):
    hearing = hear(said="you\n", sound=struct.pack("<h", 0) * 800)
    hearing.say()
    hearing.wait_for("nothing")
    assert hearing.ended() == 0
    assert hearing.left_behind == []


# The assistant's voice mode -----------------------------------------------------


def test_voice_mode_gives_each_request_at_a_pause_and_hears_on(hear):
    hearing = hear("--converse", engine=LIVE_ENGINE, env=VOICE_MODE)
    hearing.recording()
    (hearing.fakes / "phrases").write_text("Turn the volume down.\n")
    # Speaking on, no request yet: a phrase is not yet a pause.
    time.sleep(0.5)
    assert not any(m["state"] == "heard" for m in hearing.heard)
    (hearing.fakes / "sound").write_bytes(QUIET_SOUND)
    assert hearing.wait_for("heard")["text"] == "Turn the volume down."
    (hearing.fakes / "sound").write_bytes(LOUD)
    (hearing.fakes / "phrases").write_text("Turn the volume down.\nOpen Files.\nPlease.\n")
    time.sleep(0.2)
    (hearing.fakes / "sound").write_bytes(QUIET_SOUND)
    assert hearing.wait_for("heard")["text"] == "Open Files. Please."
    # A minute without a sound, here 1.5 s, ends it.
    hearing.wait_for("nothing")
    assert hearing.ended() == 0
    assert hearing.left_behind == []


def test_a_room_that_is_never_quiet_still_ends_requests_and_voice_mode(hear):
    # A fan or music is loud all along: the engine, which tells speech from noise, decides.
    hearing = hear("--converse", engine=LIVE_ENGINE, env={**VOICE_MODE, "DICTATION_TURN_LONGEST": "0.6"})
    hearing.recording()
    (hearing.fakes / "phrases").write_text("Mute the sound.\n")
    assert hearing.wait_for("heard")["text"] == "Mute the sound."
    # No speech for a minute, here 1.5 s, ends it, noise or not.
    hearing.wait_for("nothing")
    assert hearing.ended() == 0


def test_stopping_voice_mode_delivers_what_is_left(hear):
    hearing = hear("--converse", engine=LIVE_ENGINE, env=VOICE_MODE)
    hearing.recording()
    (hearing.fakes / "phrases").write_text("What time is it\n")
    hearing.wait_for("draft", text="What time is it")
    hearing.do("stop")
    assert hearing.wait_for("done")["text"] == "What time is it"
    assert hearing.ended() == 0


def test_voice_mode_ends_when_its_engine_fails_and_keeps_no_recording(hear):
    hearing = hear("--converse", engine="#!/bin/bash\nexit 3\n", env=VOICE_MODE)
    assert hearing.wait_for("failed")
    assert hearing.ended() == 1
    assert hearing.left_behind == []


# The way out --------------------------------------------------------------------


@pytest.mark.parametrize(
    "discard",
    [
        lambda h: h.do("discard"),
        lambda h: h.process.stdin.close(),
        lambda h: h.process.send_signal(signal.SIGINT),
        lambda h: h.process.send_signal(signal.SIGTERM),
    ],
    ids=["asked", "the caller ended", "interrupted", "terminated"],
)
def test_every_way_of_discarding_leaves_nothing(hear, discard):
    hearing = hear(said="Secret\n")
    hearing.recording()
    discard(hearing)
    assert hearing.ended() == 130
    assert hearing.file("engine-writing") is None
    assert hearing.left_behind == []


def test_discarding_while_writing_it_down_leaves_nothing(hear):
    hearing = hear(waits=True, said="Secret\n")
    hearing.say()
    hearing.wait_for_file("engine-writing")
    hearing.do("discard")
    assert hearing.ended() == 130
    assert hearing.left_behind == []


def test_discarding_stops_a_hung_engine(hear):
    hearing = hear(said="Tajne.\n", hangs=1)
    hearing.recording()
    hearing.do("discard")
    assert hearing.ended() == 130
    assert hearing.left_behind == []


# Failing ------------------------------------------------------------------------


def test_recorder_failure_is_reported(hear):
    hearing = hear(recorder=RECORDER_FAILS)
    assert hearing.wait_for("failed")
    assert hearing.ended() == 1
    assert hearing.left_behind == []


def test_a_failed_engine_goes_over_the_recording_again(hear):
    hearing = hear(fails=1, said="Dzień dobry.\n")
    hearing.say()
    assert hearing.wait_for("done")["text"] == "Dzień dobry."
    assert len(hearing.file("engine-runs").splitlines()) == 2
    assert (hearing.fakes / "engine-audio").read_bytes().startswith(LOUD)
    assert hearing.left_behind == []


def test_a_hung_engine_goes_over_the_recording_again_with_no_draft(hear):
    hearing = hear(hangs=1, said="Dzień dobry.\n", draft={"draft": "Dzień", "tail": ""})
    hearing.say()
    assert hearing.wait_for("done")["text"] == "Dzień dobry."
    assert [m["state"] for m in hearing.heard].count("draft") == 1


def test_an_engine_that_fails_again_fails(hear):
    hearing = hear(fails=2, said="Lost.\n")
    hearing.say()
    hearing.wait_for("failed")
    assert hearing.ended() == 1
    assert hearing.left_behind == []


# Sounds -------------------------------------------------------------------------


def test_no_sounds_unless_wanted(hear):
    hearing = hear(said="Hello\n")
    hearing.say()
    hearing.wait_for("done")
    assert hearing.file("played") is None


def test_wanted_sounds_mark_the_start_and_the_stop(hear):
    hearing = hear(said="Hello\n", env={"DICTATION_SOUNDS": "1"})
    hearing.say()
    hearing.wait_for("done")
    assert len(hearing.file("played").splitlines()) == 2
