"""desktop/dictation/hear, with a made-up recorder, engine, and player. Every path
ends with the words, or with nothing, and leaves no audio behind."""

import contextlib
import importlib.machinery
import importlib.util
import json
import os
import pathlib
import queue
import signal
import socket
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
# each line of "said" as a phrase. Files in FAKES make it say a phrase has begun
# first ("engine-speech"), wait for "go" ("engine-waits"), or hang or fail for that many
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
sys.stdout.write(mark("engine-speech"))
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
# comes out as a phrase at once, or "<speech>" as a phrase begun; it ends when the
# audio does.
LIVE_ENGINE = """#!/usr/bin/python3
import json, os, pathlib, sys, threading, time
fakes = pathlib.Path(os.environ["FAKES"])
ended = threading.Event()
def drain():
    # How much audio came, for tests to read.
    count = 0
    while data := sys.stdin.buffer.read1(65536):
        count += len(data)
        (fakes / "engine-bytes").write_text(str(count))
    ended.set()
threading.Thread(target=drain, daemon=True).start()
told = 0
while True:
    path = fakes / "phrases"
    lines = path.read_text().splitlines() if path.exists() else []
    for line in lines[told:]:
        # "words|0.9": a phrase with Smart Turn's judgement.
        words, _, turn = line.partition("|")
        print(json.dumps({"speech": True} if line == "<speech>" else {"final": words, **({"turn": float(turn)} if turn else {})}), flush=True)
    # Rewriting the file empties it for a moment: only ever go on.
    told = max(told, len(lines))
    if ended.is_set():
        break
    time.sleep(0.02)
"""
PLAYER = '#!/bin/bash\necho "$1" >>"$FAKES/played"\n'
VOICE_MODE = {"DICTATION_TURN_PAUSE": "0.3", "DICTATION_CONVERSE_QUIET": "1.5"}


class Hearing:
    def __init__(self, tmp_path, *args, recorder=RECORDER, said="", sound=LOUD, env=None, speech=False, waits=False,
                 hangs=0, fails=0, parakeet=True, engine=ENGINE, service=False):  # fmt: skip
        self.fakes = tmp_path / "fakes"
        self.runtime = tmp_path / "runtime"
        self.fakes.mkdir()
        self.runtime.mkdir()
        if service:
            # speech-model.socket, which only needs to be there.
            self.service = socket.socket(socket.AF_UNIX)
            self.service.bind(str(self.runtime / "speech-model.sock"))
        (self.fakes / "said").write_text(said)
        (self.fakes / "sound").write_bytes(sound)
        if speech:
            (self.fakes / "engine-speech").write_text(json.dumps({"speech": True}) + "\n")
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


@pytest.mark.parametrize("said", [".\n", " ?\n...\n", "\u2026\n"])
def test_marks_with_no_word_are_nothing(hear, said):
    # Noise can come out as a mark, which would be copied as if it were words.
    hearing = hear(said=said)
    hearing.say()
    hearing.wait_for("nothing")
    assert hearing.ended() == 0


def test_marks_after_words_are_left_out(hear):
    hearing = hear(said="Hello.\n.\n")
    hearing.say()
    assert hearing.wait_for("done")["text"] == "Hello."


def test_the_engine_hears_the_recording_with_the_models(hear):
    hearing = hear(said="Tak.\n")
    hearing.recording()
    hearing.wait_for_file("engine-runs")
    hearing.do("stop")
    hearing.wait_for("done")
    # Live, then the whole recording once more at the stop, for the words that go in.
    assert hearing.file("engine-runs") == f"{hearing.fakes}\n--recorded {hearing.fakes}\n"
    assert (hearing.fakes / "engine-audio").read_bytes().startswith(LOUD)


def test_a_dictation_longer_than_a_minute_keeps_its_live_phrases(hear):
    hearing = hear(said="Tak.\n", env={"DICTATION_AGAIN_UP_TO": "0"})
    hearing.recording()
    hearing.wait_for_file("engine-runs")
    hearing.do("stop")
    assert hearing.wait_for("done")["text"] == "Tak."
    assert hearing.file("engine-runs") == f"{hearing.fakes}\n"


def test_with_the_speech_model_service_the_engine_goes_through_it(hear):
    # The model then stays loaded between recordings (test_speech_model.py).
    hearing = hear(said="Tak.\n", service=True)
    hearing.recording()
    hearing.wait_for_file("engine-runs")
    hearing.do("stop")
    assert hearing.wait_for("done")["text"] == "Tak."
    service = hearing.runtime / "speech-model.sock"
    assert hearing.file("engine-runs") == f"--connect {service}\n--connect {service} --recorded\n"


def test_a_phrase_begun_is_said_while_listening_and_its_words_when_it_ends(hear):
    hearing = hear(engine=LIVE_ENGINE)
    hearing.recording()
    (hearing.fakes / "phrases").write_text("<speech>\nDzień dobry.\n")
    hearing.wait_for("speaking")
    message = hearing.wait_for("draft")
    assert (message["text"], message["tail"]) == ("Dzień dobry.", "")


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


@pytest.mark.parametrize(
    ("said", "ends"),
    [
        ("Turn the volume down.", "finished"),
        ("Jaka jest pogoda?", "finished"),
        ("Gdzie on jest?", "finished"),
        ("Wyślę ci adres i", "leading"),
        # A full stop where the engine cut a phrase short is no end.
        ("Wyślę ci adres i.", "leading"),
        ("Open the files and", "leading"),
        ("Spotkajmy się jutro,", "leading"),
        ("Yyy", "leading"),
        ("Open files", ""),
        ("", ""),
    ],
)
def test_how_the_words_end_tells_whether_the_person_is_done(said, ends):
    loader = importlib.machinery.SourceFileLoader("hear", str(HEAR))
    spec = importlib.util.spec_from_loader("hear", loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    assert module.ending(said) == ends


def test_voice_mode_waits_longer_after_words_that_lead_on(hear):
    # The pause is 0.4 s here: 0.2 s after a sentence's end, 0.8 s after "and".
    hearing = hear("--converse", engine=LIVE_ENGINE, env={**VOICE_MODE, "DICTATION_TURN_PAUSE": "0.4"})
    hearing.recording()
    (hearing.fakes / "phrases").write_text("Send it to Anna and\n")
    hearing.wait_for("draft", text="Send it to Anna and")
    # Quiet from now on.
    (hearing.fakes / "sound").write_bytes(QUIET_SOUND)
    time.sleep(0.5)
    assert not any(m["state"] == "heard" for m in hearing.heard), "after 'and', 0.5 s is not enough"
    assert hearing.wait_for("heard")["text"] == "Send it to Anna and"
    (hearing.fakes / "sound").write_bytes(LOUD)
    (hearing.fakes / "phrases").write_text("Send it to Anna and\nWhat time is it?\n")
    hearing.wait_for("draft", text="What time is it?")
    (hearing.fakes / "sound").write_bytes(QUIET_SOUND)
    began = time.monotonic()
    assert hearing.wait_for("heard")["text"] == "What time is it?"
    assert time.monotonic() - began < 0.4, "a finished question goes sooner than the plain pause"


@pytest.mark.parametrize(
    ("ends", "turn", "scale"),
    [
        # Without Smart Turn, the words alone.
        ("finished", None, 0.5),
        ("", None, 1),
        ("leading", None, 2),
        # The voice says done.
        ("finished", 0.9, 0.3),
        ("", 0.9, 0.5),
        ("leading", 0.9, 1),
        # The voice says not done, whatever full stop the engine put.
        ("finished", 0.1, 1),
        ("", 0.1, 1.5),
        ("leading", 0.1, 2),
    ],
)
def test_the_voice_decides_and_words_that_lead_on_only_add_to_the_wait(ends, turn, scale):
    loader = importlib.machinery.SourceFileLoader("hear", str(HEAR))
    spec = importlib.util.spec_from_loader("hear", loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    assert module.pause_scale(ends, turn) == scale


def test_voice_mode_waits_while_the_voice_says_the_person_is_not_done(hear):
    # The pause is 0.4 s here: a full stop alone would make it 0.2 s, but the
    # voice says not done, which keeps it at 0.4 s.
    hearing = hear("--converse", engine=LIVE_ENGINE, env={**VOICE_MODE, "DICTATION_TURN_PAUSE": "0.4"})
    hearing.recording()
    (hearing.fakes / "phrases").write_text("Wyślę ci adres.|0.05\n")
    hearing.wait_for("draft", text="Wyślę ci adres.")
    (hearing.fakes / "sound").write_bytes(QUIET_SOUND)
    time.sleep(0.25)
    assert not any(m["state"] == "heard" for m in hearing.heard)
    assert hearing.wait_for("heard")["text"] == "Wyślę ci adres."


def test_voice_mode_makes_no_request_while_a_phrase_goes_on(hear):
    hearing = hear("--converse", engine=LIVE_ENGINE, env=VOICE_MODE)
    hearing.recording()
    # A phrase, then another begun: quiet as it may be, the person is not done.
    (hearing.fakes / "phrases").write_text("Turn the volume\n<speech>\n")
    (hearing.fakes / "sound").write_bytes(QUIET_SOUND)
    hearing.wait_for("speaking")
    time.sleep(0.8)
    assert not any(m["state"] == "heard" for m in hearing.heard)
    (hearing.fakes / "phrases").write_text("Turn the volume\n<speech>\ndown.\n")
    assert hearing.wait_for("heard")["text"] == "Turn the volume down."


def test_voice_mode_hears_nothing_while_the_assistant_speaks(hear):
    hearing = hear("--converse", engine=LIVE_ENGINE, env=VOICE_MODE)
    hearing.recording()
    hearing.do("pause")
    time.sleep(0.3)
    given = hearing.file("engine-bytes")
    # Its own voice, loud as it is, goes nowhere; and a minute, here 1.5 s, of
    # the assistant speaking does not end voice mode.
    time.sleep(2.2)
    assert hearing.process.poll() is None
    assert hearing.file("engine-bytes") == given
    hearing.do("resume")
    (hearing.fakes / "phrases").write_text("Thanks.\n")
    (hearing.fakes / "sound").write_bytes(QUIET_SOUND)
    assert hearing.wait_for("heard")["text"] == "Thanks."


def test_stopping_voice_mode_delivers_what_is_left(hear):
    hearing = hear("--converse", engine=LIVE_ENGINE, env=VOICE_MODE)
    hearing.recording()
    (hearing.fakes / "phrases").write_text("What time is it\n")
    hearing.wait_for("draft", text="What time is it")
    hearing.do("stop")
    assert hearing.wait_for("done")["text"] == "What time is it"
    assert hearing.ended() == 0


def test_ending_voice_mode_mid_phrase_is_at_once_and_delivers_nothing(hear):
    # As the shell ends it, on a right click or a tap on Super: no wait for the
    # engine, and no last request whose answer would never show.
    hearing = hear("--converse", engine=LIVE_ENGINE, env=VOICE_MODE)
    hearing.recording()
    (hearing.fakes / "phrases").write_text("Open the\n")
    hearing.wait_for("draft", text="Open the")
    hearing.do("discard")
    assert hearing.process.wait(2) == 130
    rest = []
    with contextlib.suppress(queue.Empty):
        while True:
            rest.append(hearing.lines.get(timeout=0.5))
    assert not [m for m in hearing.heard + rest if m["state"] in ("heard", "done")]
    assert hearing.left_behind == []


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
    hearing.recording()
    hearing.wait_for_file("engine-runs")
    hearing.do("stop")
    assert hearing.wait_for("done")["text"] == "Dzień dobry."
    assert len(hearing.file("engine-runs").splitlines()) == 2
    assert (hearing.fakes / "engine-audio").read_bytes().startswith(LOUD)
    assert hearing.left_behind == []


def test_a_hung_engine_goes_over_the_recording_again_with_no_draft(hear):
    hearing = hear(hangs=1, said="Dzień dobry.\n", speech=True)
    hearing.recording()
    hearing.wait_for_file("engine-runs")
    hearing.do("stop")
    assert hearing.wait_for("done")["text"] == "Dzień dobry."
    states = [m["state"] for m in hearing.heard]
    assert (states.count("speaking"), states.count("draft")) == (1, 0)


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
