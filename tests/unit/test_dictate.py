"""desktop/dictation/dictate, with a made-up compositor, window, recorder, Whisper,
keyboard, and clipboard. Every path says where the text goes, and that nothing
goes anywhere else."""

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
import wave

import pytest

DICTATE = pathlib.Path(__file__).parents[2] / "desktop" / "dictation" / "dictate"

LOUD = struct.pack("<h", 20000) * 800
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
WHISPER = """#!/bin/bash
echo "$*" >>"$FAKES/whisper-args"
echo "whisper_print_progress_callback: progress =  40%" >&2
cat "$FAKES/said"
"""
WHISPER_WAITS = """#!/bin/bash
touch "$FAKES/whispering"
until [ -e "$FAKES/go" ]; do sleep 0.02; done
exec cat "$FAKES/said"
"""
WHISPER_FAILS_ONCE = """#!/bin/bash
if [ ! -e "$FAKES/failed" ]; then touch "$FAKES/failed"; exit 1; fi
ls "$XDG_RUNTIME_DIR"/dictation-*/ >"$FAKES/kept"
cat "$FAKES/said"
"""
KEYBOARD = """#!/bin/bash
echo "$*" >"$FAKES/wtype-args"
cat >"$FAKES/typed"
"""
CLIPBOARD = '#!/bin/bash\ncat >"$FAKES/copied"\n'
PLAYER = '#!/bin/bash\necho "$1" >>"$FAKES/played"\n'
WINDOW = """#!/bin/bash
cat "$FAKES/window"
"""
BROWSER = {"address": "0xa", "class": "firefox", "xwayland": False}
OTHER = {"address": "0xb", "class": "chat", "xwayland": False}

REGISTRY, SEAT, MANAGER, METHOD = 2, 3, 4, 5


def wl_string(text):
    data = text.encode() + b"\0"
    return struct.pack("<I", len(data)) + data + b"\0" * (-len(data) % 4)


class Compositor:
    """As much of a compositor as an input method sees."""

    def __init__(self, path, available=True):
        self.available = available
        self.commits = []
        self.method_bound = threading.Event()
        self.server = socket.socket(socket.AF_UNIX)
        self.server.bind(str(path))
        self.server.listen()
        self.client = None
        self.thread = threading.Thread(target=self.serve, daemon=True)
        self.thread.start()

    def event(self, target, opcode, payload=b""):
        self.client.sendall(struct.pack("<IHH", target, opcode, 8 + len(payload)) + payload)

    def serve(self):
        self.client, _ = self.server.accept()
        buffer = b""
        pending = None
        while True:
            try:
                data = self.client.recv(65536)
            except OSError:
                return
            if not data:
                return
            buffer += data
            while len(buffer) >= 8:
                target, word = struct.unpack_from("<II", buffer)
                opcode, size = word & 0xFFFF, word >> 16
                if len(buffer) < size:
                    break
                payload, buffer = buffer[8:size], buffer[size:]
                if target == 1 and opcode == 1:
                    for name, interface in ((1, "wl_seat"), (2, "zwp_input_method_manager_v2")):
                        self.event(REGISTRY, 0, struct.pack("<I", name) + wl_string(interface) + struct.pack("<I", 1))
                elif target == MANAGER and opcode == 0:
                    if not self.available:
                        self.event(METHOD, 6)
                    self.method_bound.set()
                elif target == METHOD and opcode == 0:
                    size = struct.unpack_from("<I", payload)[0]
                    pending = payload[4 : 3 + size].decode()
                elif target == METHOD and opcode == 3:
                    self.commits.append(pending)

    def focus_field(self, before="", purpose=0, hint=0, selected=False):
        self.method_bound.wait(5)
        cursor = len(before.encode())
        self.event(METHOD, 0)
        self.event(METHOD, 2, wl_string(before) + struct.pack("<II", cursor, 0 if selected else cursor))
        self.event(METHOD, 4, struct.pack("<II", hint, purpose))
        self.event(METHOD, 5)

    def leave_field(self):
        self.event(METHOD, 1)
        self.event(METHOD, 5)


class Dictation:
    def __init__(self, tmp_path, recorder=RECORDER, whisper=WHISPER, said="", language="pl", window=BROWSER,
                 compositor=True, available=True, sound=LOUD, held=False, env=None):  # fmt: skip
        self.fakes = tmp_path / "fakes"
        self.runtime = tmp_path / "runtime"
        self.fakes.mkdir()
        self.runtime.mkdir()
        (self.fakes / "said").write_text(said)
        (self.fakes / "sound").write_bytes(sound)
        self.window(window)
        fakes = [("pw-record", recorder), ("whisper-cli", whisper), ("wtype", KEYBOARD), ("wl-copy", CLIPBOARD),
                 ("hyprctl", WINDOW), ("pw-play", PLAYER)]  # fmt: skip
        for name, script in fakes:
            path = self.fakes / name
            path.write_text(script)
            path.chmod(0o755)
        self.compositor = Compositor(self.runtime / "test", available) if compositor else None
        self.process = subprocess.Popen(
            [DICTATE, language, *(["--held"] if held else [])],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            text=True,
            env={
                **os.environ,
                "PATH": f"{self.fakes}:{os.environ['PATH']}",
                "FAKES": str(self.fakes),
                "XDG_RUNTIME_DIR": str(self.runtime),
                "WAYLAND_DISPLAY": "test" if compositor else "none",
                "DICTATION_PARAKEET": "/nonexistent",
                **(env or {}),
            },
        )
        self.lines = queue.Queue()
        self.heard = []
        threading.Thread(target=self.read, daemon=True).start()
        if self.compositor:
            self.compositor.method_bound.wait(5)

    def read(self):
        for line in self.process.stdout:
            self.lines.put(json.loads(line))

    def window(self, window):
        (self.fakes / "window").write_text(json.dumps(window))

    def do(self, what, **more):
        self.process.stdin.write(json.dumps({"do": what, **more}) + "\n")
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
                if state == "done":
                    self.process.wait(10)
                    self.compositor and self.compositor.thread.join(5)
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
    def inserted(self):
        return self.compositor.commits if self.compositor else []

    @property
    def typed(self):
        return self.file("typed")

    @property
    def left_behind(self):
        return [path for path in self.runtime.iterdir() if path.name != "test"]


@pytest.fixture
def dictate(tmp_path):
    started = []

    def start(**kwargs):
        started.append(Dictation(tmp_path, **kwargs))
        return started[-1]

    yield start
    for dictation in started:
        dictation.process.kill()
        dictation.process.wait()


# A field that stays: straight in, with no card -----------------------------


def test_text_goes_straight_into_the_field_as_one_text(dictate):
    dictation = dictate(said=" Dzień dobry,\n wszystkim.\n")
    dictation.compositor.focus_field()
    dictation.say()
    assert dictation.wait_for("done")["text"] == "Dzień dobry, wszystkim."
    assert dictation.ended() == 0
    assert dictation.inserted == ["Dzień dobry, wszystkim."]
    assert dictation.typed is None, "keys could press shortcuts"
    assert dictation.left_behind == []


def test_a_terminal_is_a_field_and_no_line_ends_so_nothing_runs(dictate):
    dictation = dictate(said="rm -rf\n /home\n")
    dictation.compositor.focus_field(purpose=13)
    dictation.say()
    dictation.wait_for("done")
    assert dictation.inserted == ["rm -rf /home"]


def test_control_characters_never_pass(dictate):
    dictation = dictate(said="safe\x1b[31m text\x07\n")
    dictation.compositor.focus_field()
    dictation.say()
    dictation.wait_for("done")
    assert all(c.isprintable() for c in dictation.inserted[0])


@pytest.mark.parametrize(
    "before, selected, expected",
    [
        ("Hello", False, " there"),
        ("Hello ", False, "there"),
        ("(", False, "there"),
        ("", False, "there"),
        ("ąć", False, " there"),
        ("Hello", True, "there"),
    ],
)
def test_a_space_goes_where_the_field_needs_one(dictate, before, selected, expected):
    dictation = dictate(said="there\n")
    dictation.compositor.focus_field(before=before, selected=selected)
    dictation.say()
    dictation.wait_for("done")
    assert dictation.inserted == [expected]


def test_moving_to_a_field_before_the_stop_is_where_it_goes(dictate):
    dictation = dictate(said="Hello\n")
    dictation.compositor.focus_field()
    dictation.recording()
    dictation.window(OTHER)
    dictation.compositor.focus_field()
    time.sleep(0.2)
    dictation.do("stop")
    dictation.wait_for("done")
    assert dictation.inserted == ["Hello"]


# Moved while it was written down: it waits, so it lands in nothing new ------


def test_another_window_while_writing_waits(dictate):
    dictation = dictate(whisper=WHISPER_WAITS, said="Private\n")
    dictation.compositor.focus_field()
    dictation.say()
    dictation.wait_for_file("whispering")
    dictation.window(OTHER)
    dictation.compositor.focus_field()
    time.sleep(0.2)
    (dictation.fakes / "go").touch()
    message = dictation.wait_for("waiting", where="field")
    assert message["app"] == "chat"
    assert dictation.inserted == []


def test_another_field_in_the_same_window_while_writing_waits(dictate):
    dictation = dictate(whisper=WHISPER_WAITS, said="Private\n")
    dictation.compositor.focus_field()
    dictation.say()
    dictation.wait_for_file("whispering")
    dictation.compositor.focus_field()
    time.sleep(0.2)
    (dictation.fakes / "go").touch()
    dictation.wait_for("waiting", where="field")
    assert dictation.inserted == []


def test_a_field_that_appears_only_after_the_stop_waits(dictate):
    dictation = dictate(whisper=WHISPER_WAITS, said="Hello\n")
    dictation.say()
    dictation.wait_for_file("whispering")
    dictation.compositor.focus_field()
    time.sleep(0.2)
    (dictation.fakes / "go").touch()
    dictation.wait_for("waiting", where="field")
    assert dictation.inserted == []


# No place for it: it waits, and nothing is typed ----------------------------


def test_a_window_with_no_field_waits(dictate):
    dictation = dictate(said="Hello\n")
    dictation.say()
    message = dictation.wait_for("waiting")
    assert (message["where"], message["app"], message["text"]) == ("none", "firefox", "Hello")
    assert dictation.typed is None and dictation.inserted == []


def test_no_window_waits_and_keys_are_refused(dictate):
    dictation = dictate(said="Hello\n", window={})
    dictation.say()
    assert dictation.wait_for("waiting")["where"] == "nowindow"
    dictation.do("type")
    time.sleep(0.3)
    assert dictation.typed is None
    assert dictation.process.poll() is None


def test_xwayland_never_tells_so_it_is_unknown(dictate):
    dictation = dictate(said="Hello\n", window={"address": "0xc", "class": "old", "xwayland": True})
    dictation.say()
    assert dictation.wait_for("waiting")["where"] == "unknown"
    assert dictation.typed is None


def test_without_a_compositor_it_is_unknown(dictate):
    dictation = dictate(said="Hello\n", compositor=False)
    dictation.say()
    assert dictation.wait_for("waiting")["where"] == "unknown"


def test_with_another_input_method_running_it_is_unknown(dictate):
    dictation = dictate(said="Hello\n", available=False)
    dictation.say()
    assert dictation.wait_for("waiting")["where"] == "unknown"


# Passwords: never ------------------------------------------------------------


@pytest.mark.parametrize("purpose, hint", [(8, 0), (9, 0), (0, 0x40)])
def test_a_secret_field_refuses_both_ways_in(dictate, purpose, hint):
    dictation = dictate(said="Hello\n")
    dictation.compositor.focus_field(purpose=purpose, hint=hint)
    dictation.say()
    assert dictation.wait_for("waiting")["where"] == "password"
    dictation.do("insert")
    dictation.do("type")
    time.sleep(0.9)
    assert dictation.inserted == [] and dictation.typed is None
    assert dictation.process.poll() is None


# What the person chooses ------------------------------------------------------


def test_a_field_clicked_while_waiting_takes_it_when_asked_and_not_before(dictate):
    dictation = dictate(said="Hello\n")
    dictation.say()
    dictation.wait_for("waiting", where="none")
    dictation.compositor.focus_field()
    dictation.wait_for("waiting", where="field")
    assert dictation.inserted == []
    dictation.do("insert")
    assert dictation.wait_for("done")["text"] == "Hello"
    assert dictation.inserted == ["Hello"]


def test_insert_waits_for_the_field_to_come_back(dictate):
    # The shell gives the focus back from the card just before.
    dictation = dictate(said="Hello\n")
    dictation.say()
    dictation.wait_for("waiting", where="none")
    dictation.do("insert")
    time.sleep(0.1)
    dictation.compositor.focus_field()
    dictation.wait_for("done")
    assert dictation.inserted == ["Hello"]


def test_insert_with_no_field_keeps_the_text_waiting(dictate):
    dictation = dictate(said="Hello\n")
    dictation.say()
    dictation.wait_for("waiting")
    dictation.do("insert")
    time.sleep(0.9)
    assert dictation.process.poll() is None and dictation.inserted == []
    dictation.do("copy")
    dictation.wait_for("done")
    assert dictation.file("copied") == "Hello"


def test_type_uses_keys_on_standard_input_so_it_is_never_an_option(dictate):
    dictation = dictate(said="--help\n")
    dictation.say()
    dictation.wait_for("waiting")
    dictation.do("type")
    assert dictation.wait_for("done")["text"] == "--help"
    assert dictation.file("wtype-args").strip() == "-"
    assert dictation.typed == "--help"


def test_edited_text_is_what_is_delivered(dictate):
    dictation = dictate(said="Helo\n")
    dictation.say()
    dictation.wait_for("waiting")
    dictation.do("text", text="Hello\n")
    dictation.do("copy")
    assert dictation.wait_for("done")["text"] == "Hello"
    assert dictation.file("copied") == "Hello"


def test_keep_talking_joins_the_text(dictate):
    dictation = dictate(said="One.\n")
    dictation.say()
    dictation.wait_for("waiting", text="One.")
    (dictation.fakes / "said").write_text("Two.\n")
    (dictation.fakes / "recording").unlink()
    dictation.do("add")
    dictation.say()
    dictation.wait_for("waiting", text="One. Two.")


def test_keep_talking_never_delivers_by_itself(dictate):
    dictation = dictate(said="One.\n")
    dictation.say()
    dictation.wait_for("waiting")
    dictation.compositor.focus_field()
    (dictation.fakes / "recording").unlink()
    dictation.do("add")
    dictation.say()
    dictation.wait_for("waiting", text="One. One.")
    assert dictation.inserted == []


def test_silence_in_keep_talking_keeps_the_text(dictate):
    dictation = dictate(said="One.\n")
    dictation.say()
    dictation.wait_for("waiting")
    (dictation.fakes / "said").write_text(" [BLANK_AUDIO]\n")
    (dictation.fakes / "recording").unlink()
    dictation.do("add")
    dictation.say()
    dictation.wait_for("waiting", text="One.")


def test_held_text_comes_back_to_be_delivered(dictate):
    dictation = dictate(held=True)
    dictation.do("hold", text="From before")
    dictation.wait_for("waiting", text="From before")
    assert not (dictation.fakes / "recording").exists(), "no microphone for this"
    dictation.compositor.focus_field()
    dictation.do("insert")
    dictation.wait_for("done")
    assert dictation.inserted == ["From before"]


# Understanding ----------------------------------------------------------------


def whisper_language(dictation):
    args = dictation.file("whisper-args").split()
    return args[args.index("-l") + 1]


def test_whisper_hears_the_language_and_the_recording(dictate):
    dictation = dictate(said="Hello\n")
    dictation.say()
    dictation.wait_for("waiting")
    args = dictation.file("whisper-args").split()
    assert whisper_language(dictation) == "pl"
    assert args[args.index("-f") + 1].endswith(".wav")


def test_a_language_whisper_does_not_know_is_detected(dictate):
    # Whisper would succeed with no text for "ara", as a keyboard layout may say.
    dictation = dictate(said="Hello\n", language="ara")
    dictation.say()
    dictation.wait_for("waiting")
    assert whisper_language(dictation) == "auto"


def test_the_language_can_change_while_listening(dictate):
    dictation = dictate(said="Hello\n")
    dictation.recording()
    dictation.do("language", language="auto")
    dictation.do("stop")
    dictation.wait_for("waiting")
    assert whisper_language(dictation) == "auto"


def test_the_recording_is_a_real_sound_file(dictate, tmp_path):
    keep = tmp_path / "copy.wav"
    whisper = f'#!/bin/bash\nwhile [ $# -gt 0 ]; do [ "$1" = -f ] && cp "$2" {keep}; shift; done\necho Hello\n'
    dictation = dictate(whisper=whisper)
    dictation.say()
    dictation.wait_for("waiting")
    with wave.open(str(keep)) as sound:
        assert (sound.getframerate(), sound.getnchannels(), sound.getsampwidth()) == (16000, 1, 2)
        assert sound.getnframes() > 0


def test_progress_is_reported(dictate):
    dictation = dictate(said="Hello\n")
    dictation.say()
    dictation.wait_for("writing", progress=40)


# Hearing ------------------------------------------------------------------------


def test_the_level_follows_the_sound(dictate):
    dictation = dictate()
    dictation.recording()
    assert dictation.wait_for("listening", quiet=False, idle=False, level=1)


def test_a_microphone_that_hears_nothing_says_so(dictate):
    dictation = dictate(sound=b"\0" * 1600, env={"DICTATION_QUIET": "0.2"})
    dictation.recording()
    assert dictation.wait_for("listening", quiet=True)["level"] == 0


def test_a_long_silence_after_speech_asks_then_stops_and_keeps_the_text(dictate):
    env = {"DICTATION_IDLE": "0.2", "DICTATION_GIVE_UP": "0.8"}
    dictation = dictate(said="Hello\n", env=env)
    dictation.recording()
    dictation.wait_for("listening", idle=False, quiet=False)
    (dictation.fakes / "sound").write_bytes(b"\0" * 1600)
    dictation.wait_for("listening", idle=True, quiet=False)
    assert dictation.wait_for("waiting")["text"] == "Hello"


def test_giving_up_on_silence_stops_listening(dictate):
    dictation = dictate(sound=b"\0" * 1600, said=" [BLANK_AUDIO]\n", env={"DICTATION_GIVE_UP": "0.3"})
    dictation.recording()
    dictation.wait_for("writing")
    dictation.wait_for("nothing")
    assert dictation.ended() == 0


def test_silence_delivers_nothing_and_says_so(dictate):
    dictation = dictate(said=" [BLANK_AUDIO]\n")
    dictation.compositor.focus_field()
    dictation.say()
    dictation.wait_for("nothing")
    assert dictation.ended() == 0
    assert dictation.inserted == []
    assert dictation.left_behind == []


# The way out --------------------------------------------------------------------


@pytest.mark.parametrize(
    "discard",
    [
        lambda d: d.do("discard"),
        lambda d: d.process.stdin.close(),
        lambda d: d.process.send_signal(signal.SIGINT),
        lambda d: d.process.send_signal(signal.SIGTERM),
    ],
    ids=["asked", "the shell ended", "interrupted", "terminated"],
)
def test_every_way_of_discarding_leaves_nothing(dictate, discard):
    dictation = dictate(said="Secret\n")
    dictation.compositor.focus_field()
    dictation.recording()
    discard(dictation)
    assert dictation.ended() == 130
    assert dictation.file("whisper-args") is None
    assert dictation.inserted == []
    assert dictation.left_behind == []


def test_discarding_while_writing_it_down_delivers_nothing(dictate):
    dictation = dictate(whisper=WHISPER_WAITS, said="Secret\n")
    dictation.compositor.focus_field()
    dictation.say()
    dictation.wait_for_file("whispering")
    dictation.do("discard")
    assert dictation.ended() == 130
    assert dictation.inserted == []
    assert dictation.left_behind == []


def test_discarding_a_waiting_text_leaves_nothing(dictate):
    dictation = dictate(said="Secret\n")
    dictation.say()
    dictation.wait_for("waiting")
    dictation.do("discard")
    assert dictation.ended() == 130
    assert dictation.left_behind == []


# Failing ------------------------------------------------------------------------


def test_recorder_failure_is_reported(dictate):
    dictation = dictate(recorder=RECORDER_FAILS)
    dictation.wait_for("failed")
    assert dictation.ended() == 1
    assert dictation.left_behind == []


def test_recorder_failure_keeps_text_that_is_waiting(dictate):
    dictation = dictate(said="One.\n")
    dictation.say()
    dictation.wait_for("waiting")
    (dictation.fakes / "pw-record").write_text(RECORDER_FAILS)
    dictation.do("add")
    dictation.wait_for("waiting", text="One.")


def test_whisper_failure_keeps_the_audio_to_try_again(dictate):
    dictation = dictate(whisper=WHISPER_FAILS_ONCE, said="Hello\n")
    dictation.compositor.focus_field()
    dictation.say()
    dictation.wait_for("failed")
    assert dictation.process.poll() is None
    dictation.do("retry")
    assert dictation.wait_for("done")["text"] == "Hello"
    assert ".wav" in dictation.file("kept")
    assert dictation.left_behind == []


def test_whisper_failure_can_be_discarded(dictate):
    dictation = dictate(whisper=WHISPER_FAILS_ONCE, said="Hello\n")
    dictation.say()
    dictation.wait_for("failed")
    dictation.do("discard")
    assert dictation.ended() == 130
    assert dictation.left_behind == []


# Sounds -------------------------------------------------------------------------


def test_no_sounds_unless_wanted(dictate):
    dictation = dictate(said="Hello\n")
    dictation.say()
    dictation.wait_for("waiting")
    assert dictation.file("played") is None


def test_wanted_sounds_mark_the_start_and_the_stop(dictate):
    dictation = dictate(said="Hello\n", env={"DICTATION_SOUNDS": "1"})
    dictation.say()
    dictation.wait_for("waiting")
    assert len(dictation.file("played").splitlines()) == 2


# Live, with the engine -----------------------------------------------------

ENGINE = """#!/bin/bash
# As the real one: says the draft at once, reads to the end, then says the phrases.
echo "$*" >"$FAKES/engine-args"
[ ! -e "$FAKES/engine-draft" ] || cat "$FAKES/engine-draft"
cat >"$FAKES/engine-audio"
[ ! -e "$FAKES/engine-hangs" ] || exec sleep 60
while [ -e "$FAKES/engine-waits" ] && [ ! -e "$FAKES/engine-go" ]; do sleep 0.02; done
[ ! -e "$FAKES/engine-fails" ] || exit 1
cat "$FAKES/engine-finals"
"""


def live(dictate, tmp_path, finals=(), draft=None, marks=(), **kwargs):
    """Dictation with a made-up engine, in place before it starts."""
    fakes = tmp_path / "engine"
    fakes.mkdir()
    engine = fakes / "dictate-engine"
    engine.write_text(ENGINE)
    engine.chmod(0o755)
    # The fakes' folder comes when Dictation makes it, so the engine reads from FAKES.
    env = {"DICTATION_ENGINE": str(engine), "DICTATION_PARAKEET": str(fakes), "DICTATION_ENGINE_WAIT": "1", **kwargs.pop("env", {})}
    prepared = tmp_path / "prepared"
    prepared.mkdir()
    (prepared / "engine-finals").write_text("".join(json.dumps({"final": text}) + "\n" for text in finals))
    if draft:
        (prepared / "engine-draft").write_text(json.dumps(draft) + "\n")
    for mark in marks:
        (prepared / mark).touch()
    engine.write_text(ENGINE.replace("$FAKES/engine-", f"{prepared}/engine-"))
    return dictate(env=env, **kwargs)


def test_phrases_become_one_text_with_no_whisper(dictate, tmp_path):
    dictation = live(dictate, tmp_path, finals=["Dzień dobry.", "Jak się masz?"], said="whisper")
    dictation.compositor.focus_field()
    dictation.say()
    assert dictation.wait_for("done")["text"] == "Dzień dobry. Jak się masz?"
    assert dictation.inserted == ["Dzień dobry. Jak się masz?"]
    assert dictation.file("whisper-args") is None
    assert dictation.left_behind == []


def test_the_engine_hears_the_recording(dictate, tmp_path):
    dictation = live(dictate, tmp_path, finals=["Tak."])
    dictation.compositor.focus_field()
    dictation.say()
    dictation.wait_for("done")
    assert (tmp_path / "prepared" / "engine-audio").read_bytes().startswith(LOUD)


def test_the_draft_goes_to_the_shell_and_nowhere_else(dictate, tmp_path):
    draft = {"draft": "Dzień", "tail": "dobry"}
    dictation = live(dictate, tmp_path, finals=["Dzień dobry."], draft=draft)
    dictation.compositor.focus_field()
    message = dictation.wait_for("draft")
    assert (message["text"], message["tail"]) == ("Dzień", "dobry")
    assert dictation.inserted == []
    assert dictation.typed is None


def test_a_window_left_after_the_stop_gets_nothing(dictate, tmp_path):
    dictation = live(dictate, tmp_path, finals=["Tajne."], marks=["engine-waits"])
    dictation.compositor.focus_field()
    dictation.say()
    dictation.wait_for("writing")
    dictation.window(OTHER)
    (tmp_path / "prepared" / "engine-go").touch()
    assert dictation.wait_for("waiting")["text"] == "Tajne."
    assert dictation.inserted == []


def test_a_failed_engine_leaves_it_to_whisper(dictate, tmp_path):
    dictation = live(dictate, tmp_path, finals=["Lost."], marks=["engine-fails"], said="Z Whispera.\n")
    dictation.compositor.focus_field()
    dictation.say()
    assert dictation.wait_for("done")["text"] == "Z Whispera."
    assert dictation.left_behind == []


def test_a_hung_engine_leaves_it_to_whisper(dictate, tmp_path):
    dictation = live(dictate, tmp_path, marks=["engine-hangs"], said="Z Whispera.\n")
    dictation.compositor.focus_field()
    dictation.say()
    assert dictation.wait_for("done")["text"] == "Z Whispera."


def test_no_engine_in_a_language_parakeet_lacks(dictate, tmp_path):
    dictation = live(dictate, tmp_path, finals=["Lost."], language="ja", said="日本語\n")
    dictation.compositor.focus_field()
    dictation.say()
    assert dictation.wait_for("done")["text"] == "日本語"
    assert not (tmp_path / "prepared" / "engine-audio").exists()


def test_any_language_is_live_as_parakeet_tells_them_apart(dictate, tmp_path):
    dictation = live(dictate, tmp_path, finals=["Dzień dobry."], language="auto", said="whisper\n")
    dictation.compositor.focus_field()
    dictation.say()
    assert dictation.wait_for("done")["text"] == "Dzień dobry."
    assert dictation.file("whisper-args") is None


def test_all_languages_leave_it_to_whisper_detecting_the_language(dictate, tmp_path):
    dictation = live(dictate, tmp_path, finals=["Lost."], language="all", said="日本語\n")
    dictation.compositor.focus_field()
    dictation.say()
    assert dictation.wait_for("done")["text"] == "日本語"
    args = dictation.file("whisper-args").split()
    assert args[args.index("-l") + 1] == "auto"


def test_a_change_to_another_language_leaves_it_to_whisper(dictate, tmp_path):
    dictation = live(dictate, tmp_path, finals=["Lost."], said="日本語\n")
    dictation.compositor.focus_field()
    dictation.recording()
    dictation.do("language", language="ja")
    dictation.do("stop")
    assert dictation.wait_for("done")["text"] == "日本語"


def test_silence_says_nothing_was_caught_with_no_whisper(dictate, tmp_path):
    dictation = live(dictate, tmp_path, said="[muzyka]\n")
    dictation.compositor.focus_field()
    dictation.say()
    dictation.wait_for("nothing")
    assert dictation.ended() == 0
    assert dictation.file("whisper-args") is None
    assert dictation.inserted == []


def test_discarding_stops_the_engine_and_leaves_nothing(dictate, tmp_path):
    dictation = live(dictate, tmp_path, finals=["Tajne."], marks=["engine-hangs"])
    dictation.compositor.focus_field()
    dictation.recording()
    dictation.do("discard")
    assert dictation.ended() == 130
    assert dictation.inserted == []
    assert dictation.left_behind == []


def test_keeping_talking_adds_to_the_text(dictate, tmp_path):
    dictation = live(dictate, tmp_path, finals=["Dalej."])
    dictation.say()
    assert dictation.wait_for("waiting")["text"] == "Dalej."
    dictation.do("add")
    dictation.wait_for("listening")
    dictation.do("stop")
    assert dictation.wait_for("waiting", text="Dalej. Dalej.")


def test_words_agree_ignoring_case_and_punctuation():
    import importlib.machinery
    import importlib.util

    loader = importlib.machinery.SourceFileLoader("engine", str(DICTATE.with_name("dictate-engine")))
    spec = importlib.util.spec_from_loader("engine", loader)
    engine = importlib.util.module_from_spec(spec)
    loader.exec_module(engine)
    assert engine.agreed(["Ask", "not,", "what"], ["ask", "not", "when", "what"]) == 2
    assert engine.agreed([], ["ask"]) == 0


def test_silence_goes_to_no_engine_as_whisper_invents_words(dictate):
    dictation = dictate(said="you\n", sound=struct.pack("<h", 0) * 800)
    dictation.compositor.focus_field()
    dictation.say()
    dictation.wait_for("nothing")
    assert dictation.ended() == 0
    assert dictation.file("whisper-args") is None
    assert dictation.inserted == []
    assert dictation.left_behind == []


def test_silence_after_text_keeps_the_text(dictate, tmp_path):
    dictation = dictate(said="Dzień dobry\n")
    dictation.say()
    dictation.wait_for("waiting", text="Dzień dobry")
    (dictation.fakes / "sound").write_bytes(struct.pack("<h", 0) * 800)
    dictation.do("add")
    dictation.wait_for("listening")
    dictation.do("stop")
    assert dictation.wait_for("waiting", text="Dzień dobry")
