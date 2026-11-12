"""desktop/dictation/dictate, with a made-up compositor, window, keyboard, clipboard,
and dictation/hear, which tests/unit/test_hear.py covers. Every path says where the
text goes, and that nothing goes anywhere else."""

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

DICTATE = pathlib.Path(__file__).parents[2] / "desktop" / "dictation" / "dictate"

# As dictation/hear: listens until "stop", then says "said" as the words, or nothing.
# Files in FAKES make it fail before it listens ("cannot-hear"), say a draft
# ("draft"), stop by itself ("gives-up"), wait for "go" before the words
# ("waits"), or fail, to retry, that many times ("fails").
HEAR = """#!/usr/bin/python3
import json, os, pathlib, sys, time
fakes = pathlib.Path(os.environ["FAKES"])
def say(**message):
    print(json.dumps(message), flush=True)
def mark(name, default=""):
    path = fakes / name
    return path.read_text() if path.exists() else default
with open(fakes / "hear-runs", "a") as runs:
    runs.write(" ".join(sys.argv[1:]) + "\\n")
(fakes / "hear-pid").write_text(str(os.getpid()))
if (fakes / "cannot-hear").exists():
    say(state="failed", retry=False)
    sys.exit(1)
say(state="listening", level=1, quiet=False, idle=False)
if mark("draft"):
    say(state="draft", text=mark("draft"), tail="")
def write_down():
    say(state="writing")
    while (fakes / "waits").exists() and not (fakes / "go").exists():
        time.sleep(0.02)
    fails = int(mark("fails", "0"))
    if fails:
        (fakes / "fails").write_text(str(fails - 1))
        say(state="failed", retry=True)
        return
    said = mark("said")
    if said:
        say(state="done", text=said)
    else:
        say(state="nothing")
    sys.exit(0)
if (fakes / "gives-up").exists():
    write_down()
for line in sys.stdin:
    what = json.loads(line)["do"]
    if what == "discard":
        sys.exit(130)
    if what in ("stop", "retry"):
        write_down()
sys.exit(130)
"""
KEYBOARD = """#!/bin/bash
echo "$*" >"$FAKES/wtype-args"
cat >"$FAKES/typed"
"""
CLIPBOARD = '#!/bin/bash\ncat >"$FAKES/copied"\n'
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
    def __init__(self, tmp_path, said="", window=BROWSER, compositor=True, available=True, held=False, draft="",
                 waits=False, fails=0, hears=True, gives_up=False, real_hear=False):  # fmt: skip
        self.fakes = tmp_path / "fakes"
        self.runtime = tmp_path / "runtime"
        self.fakes.mkdir()
        self.runtime.mkdir()
        self.said(said)
        self.window(window)
        (self.fakes / "draft").write_text(draft)
        (self.fakes / "fails").write_text(str(fails))
        for name, present in (("waits", waits), ("cannot-hear", not hears), ("gives-up", gives_up)):
            if present:
                (self.fakes / name).touch()
        for name, script in (("hear", HEAR), ("wtype", KEYBOARD), ("wl-copy", CLIPBOARD), ("hyprctl", WINDOW)):
            path = self.fakes / name
            path.write_text(script)
            path.chmod(0o755)
        hearing = {"DICTATION_HEAR": str(self.fakes / "hear")}
        if real_hear:
            # With a made-up microphone and engine, as tests/unit/test_hear.py has them.
            from test_hear import ENGINE, LOUD, RECORDER

            for name, script in (("pw-record", RECORDER), ("dictate-engine", ENGINE)):
                (self.fakes / name).write_text(script)
                (self.fakes / name).chmod(0o755)
            (self.fakes / "sound").write_bytes(LOUD)
            hearing = {"DICTATION_ENGINE": str(self.fakes / "dictate-engine"), "DICTATION_PARAKEET": str(self.fakes)}
        self.compositor = Compositor(self.runtime / "test", available) if compositor else None
        self.process = subprocess.Popen(
            [DICTATE, *(["--held"] if held else [])],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            text=True,
            env={
                **os.environ,
                "PATH": f"{self.fakes}:{os.environ['PATH']}",
                "FAKES": str(self.fakes),
                "XDG_RUNTIME_DIR": str(self.runtime),
                "WAYLAND_DISPLAY": "test" if compositor else "none",
                **hearing,
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

    def said(self, text):
        (self.fakes / "said").write_text(text)

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

    def say(self):
        self.wait_for("listening")
        self.do("stop")

    def writing(self):
        """Stopped, and the words not yet out until go()."""
        self.say()
        self.wait_for("writing")

    def go(self):
        (self.fakes / "go").touch()

    def ended(self):
        return self.process.wait(10)

    def file(self, name):
        path = self.fakes / name
        return path.read_text() if path.exists() else None

    @property
    def hearing_gone(self):
        try:
            os.kill(int(self.file("hear-pid")), 0)
        except ProcessLookupError:
            return True
        return False

    @property
    def inserted(self):
        return self.compositor.commits if self.compositor else []

    @property
    def typed(self):
        return self.file("typed")


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


def test_text_goes_straight_into_the_field(dictate):
    dictation = dictate(said="Dzień dobry, wszystkim.")
    dictation.compositor.focus_field()
    dictation.say()
    assert dictation.wait_for("done")["text"] == "Dzień dobry, wszystkim."
    assert dictation.ended() == 0
    assert dictation.inserted == ["Dzień dobry, wszystkim."]
    assert dictation.typed is None, "keys could press shortcuts"


def test_it_hears_keeping_a_failure_to_retry(dictate):
    dictation = dictate()
    dictation.say()
    dictation.wait_for("nothing")
    assert dictation.file("hear-runs") == "--retry\n"


def test_control_characters_and_line_ends_never_pass(dictate):
    dictation = dictate(said="rm -rf\n /home\x1b[31m\x07")
    dictation.compositor.focus_field(purpose=13)
    dictation.say()
    dictation.wait_for("done")
    assert dictation.inserted == ["rm -rf /home [31m"]


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
    dictation = dictate(said="there")
    dictation.compositor.focus_field(before=before, selected=selected)
    dictation.say()
    dictation.wait_for("done")
    assert dictation.inserted == [expected]


def test_moving_to_a_field_before_the_stop_is_where_it_goes(dictate):
    dictation = dictate(said="Hello")
    dictation.compositor.focus_field()
    dictation.wait_for("listening")
    dictation.window(OTHER)
    dictation.compositor.focus_field()
    time.sleep(0.2)
    dictation.do("stop")
    dictation.wait_for("done")
    assert dictation.inserted == ["Hello"]


def test_where_it_stopped_by_itself_is_where_it_goes(dictate):
    dictation = dictate(said="Hello", gives_up=True)
    dictation.compositor.focus_field()
    dictation.wait_for("done")
    assert dictation.inserted == ["Hello"]


# Moved while it was written down: it waits, so it lands in nothing new ------


def test_another_window_while_writing_waits(dictate):
    dictation = dictate(waits=True, said="Private")
    dictation.compositor.focus_field()
    dictation.writing()
    dictation.window(OTHER)
    dictation.compositor.focus_field()
    time.sleep(0.2)
    dictation.go()
    message = dictation.wait_for("waiting", where="field")
    assert message["app"] == "chat"
    assert dictation.inserted == []


def test_another_field_in_the_same_window_while_writing_waits(dictate):
    dictation = dictate(waits=True, said="Private")
    dictation.compositor.focus_field()
    dictation.writing()
    dictation.compositor.focus_field()
    time.sleep(0.2)
    dictation.go()
    dictation.wait_for("waiting", where="field")
    assert dictation.inserted == []


def test_a_field_that_appears_only_after_the_stop_waits(dictate):
    dictation = dictate(waits=True, said="Hello")
    dictation.writing()
    dictation.compositor.focus_field()
    time.sleep(0.2)
    dictation.go()
    dictation.wait_for("waiting", where="field")
    assert dictation.inserted == []


def test_a_window_left_after_the_stop_gets_nothing(dictate):
    dictation = dictate(waits=True, said="Tajne.")
    dictation.compositor.focus_field()
    dictation.writing()
    dictation.window(OTHER)
    dictation.go()
    assert dictation.wait_for("waiting")["text"] == "Tajne."
    assert dictation.inserted == []


# No place for it: it waits, and nothing is typed ----------------------------


def test_a_window_with_no_field_waits(dictate):
    dictation = dictate(said="Hello")
    dictation.say()
    message = dictation.wait_for("waiting")
    assert (message["where"], message["app"], message["text"]) == ("none", "firefox", "Hello")
    assert dictation.typed is None and dictation.inserted == []


def test_no_window_waits_and_keys_are_refused(dictate):
    dictation = dictate(said="Hello", window={})
    dictation.say()
    assert dictation.wait_for("waiting")["where"] == "nowindow"
    dictation.do("type")
    time.sleep(0.3)
    assert dictation.typed is None
    assert dictation.process.poll() is None


def test_xwayland_never_tells_so_it_is_unknown(dictate):
    dictation = dictate(said="Hello", window={"address": "0xc", "class": "old", "xwayland": True})
    dictation.say()
    assert dictation.wait_for("waiting")["where"] == "unknown"
    assert dictation.typed is None


def test_without_a_compositor_it_is_unknown(dictate):
    dictation = dictate(said="Hello", compositor=False)
    dictation.say()
    assert dictation.wait_for("waiting")["where"] == "unknown"


def test_with_another_input_method_running_it_is_unknown(dictate):
    dictation = dictate(said="Hello", available=False)
    dictation.say()
    assert dictation.wait_for("waiting")["where"] == "unknown"


# Passwords: never ------------------------------------------------------------


@pytest.mark.parametrize("purpose, hint", [(8, 0), (9, 0), (0, 0x40)])
def test_a_secret_field_refuses_both_ways_in(dictate, purpose, hint):
    dictation = dictate(said="Hello")
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
    dictation = dictate(said="Hello")
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
    dictation = dictate(said="Hello")
    dictation.say()
    dictation.wait_for("waiting", where="none")
    dictation.do("insert")
    time.sleep(0.1)
    dictation.compositor.focus_field()
    dictation.wait_for("done")
    assert dictation.inserted == ["Hello"]


def test_insert_with_no_field_keeps_the_text_waiting(dictate):
    dictation = dictate(said="Hello")
    dictation.say()
    dictation.wait_for("waiting")
    dictation.do("insert")
    time.sleep(0.9)
    assert dictation.process.poll() is None and dictation.inserted == []
    dictation.do("copy")
    dictation.wait_for("done")
    assert dictation.file("copied") == "Hello"


def test_type_uses_keys_on_standard_input_so_it_is_never_an_option(dictate):
    dictation = dictate(said="--help")
    dictation.say()
    dictation.wait_for("waiting")
    dictation.do("type")
    assert dictation.wait_for("done")["text"] == "--help"
    assert dictation.file("wtype-args").strip() == "-"
    assert dictation.typed == "--help"


def test_edited_text_is_what_is_delivered(dictate):
    dictation = dictate(said="Helo")
    dictation.say()
    dictation.wait_for("waiting")
    dictation.do("text", text="Hello\n")
    dictation.do("copy")
    assert dictation.wait_for("done")["text"] == "Hello"
    assert dictation.file("copied") == "Hello"


def test_keep_talking_joins_the_text(dictate):
    dictation = dictate(said="One.")
    dictation.say()
    dictation.wait_for("waiting", text="One.")
    dictation.said("Two.")
    dictation.do("add")
    dictation.say()
    dictation.wait_for("waiting", text="One. Two.")


def test_keep_talking_never_delivers_by_itself(dictate):
    dictation = dictate(said="One.")
    dictation.say()
    dictation.wait_for("waiting")
    dictation.compositor.focus_field()
    dictation.do("add")
    dictation.say()
    dictation.wait_for("waiting", text="One. One.")
    assert dictation.inserted == []


def test_silence_in_keep_talking_keeps_the_text(dictate):
    dictation = dictate(said="One.")
    dictation.say()
    dictation.wait_for("waiting")
    dictation.said("")
    dictation.do("add")
    dictation.say()
    dictation.wait_for("waiting", text="One.")


def test_held_text_comes_back_to_be_delivered(dictate):
    dictation = dictate(held=True)
    dictation.do("hold", text="From before")
    dictation.wait_for("waiting", text="From before")
    assert dictation.file("hear-runs") is None, "no microphone for this"
    dictation.compositor.focus_field()
    dictation.do("insert")
    dictation.wait_for("done")
    assert dictation.inserted == ["From before"]


def test_held_text_stays_when_it_cannot_hear(dictate):
    dictation = dictate(held=True, hears=False)
    dictation.do("hold", text="From before")
    dictation.wait_for("waiting", text="From before")
    dictation.do("add")
    dictation.wait_for("waiting", text="From before")
    dictation.do("copy")
    assert dictation.wait_for("done")["text"] == "From before"


# While it listens ---------------------------------------------------------------


def test_what_hear_says_while_listening_goes_to_the_shell_and_nowhere_else(dictate):
    dictation = dictate(said="Dzień dobry.", draft="Dzień")
    dictation.compositor.focus_field()
    assert dictation.wait_for("listening")["level"] == 1
    assert dictation.wait_for("draft")["text"] == "Dzień"
    assert dictation.inserted == []
    assert dictation.typed is None


def test_nothing_said_delivers_nothing_and_says_so(dictate):
    dictation = dictate()
    dictation.compositor.focus_field()
    dictation.say()
    dictation.wait_for("nothing")
    assert dictation.ended() == 0
    assert dictation.inserted == []


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
def test_every_way_of_discarding_ends_hearing_and_delivers_nothing(dictate, discard):
    dictation = dictate(said="Secret")
    dictation.compositor.focus_field()
    dictation.wait_for("listening")
    discard(dictation)
    assert dictation.ended() == 130
    assert dictation.hearing_gone
    assert dictation.inserted == []


def test_discarding_while_writing_it_down_delivers_nothing(dictate):
    dictation = dictate(waits=True, said="Secret")
    dictation.compositor.focus_field()
    dictation.writing()
    dictation.do("discard")
    assert dictation.ended() == 130
    assert dictation.hearing_gone
    assert dictation.inserted == []


def test_discarding_a_waiting_text_ends(dictate):
    dictation = dictate(said="Secret")
    dictation.say()
    dictation.wait_for("waiting")
    dictation.do("discard")
    assert dictation.ended() == 130


# Failing ------------------------------------------------------------------------


def test_when_it_cannot_hear_it_fails(dictate):
    dictation = dictate(hears=False)
    dictation.wait_for("failed")
    assert dictation.ended() == 1


def test_when_it_cannot_hear_text_that_is_waiting_stays(dictate):
    dictation = dictate(said="One.")
    dictation.say()
    dictation.wait_for("waiting")
    (dictation.fakes / "cannot-hear").touch()
    dictation.do("add")
    dictation.wait_for("waiting", text="One.")


def test_a_failure_can_be_tried_again(dictate):
    dictation = dictate(fails=1, said="Hello")
    dictation.compositor.focus_field()
    dictation.say()
    dictation.wait_for("failed")
    assert dictation.process.poll() is None
    dictation.do("retry")
    assert dictation.wait_for("done")["text"] == "Hello"
    assert dictation.inserted == ["Hello"]


def test_a_failure_can_be_discarded(dictate):
    dictation = dictate(fails=1, said="Hello")
    dictation.say()
    dictation.wait_for("failed")
    dictation.do("discard")
    assert dictation.ended() == 130
    assert dictation.hearing_gone



# With the real hear ---------------------------------------------------------------


def test_with_the_real_hear_the_words_go_into_the_field_and_no_audio_stays(dictate):
    dictation = dictate(said="Dzień dobry.\n", real_hear=True)
    dictation.compositor.focus_field()
    dictation.wait_for("listening", level=1)
    dictation.do("stop")
    assert dictation.wait_for("done")["text"] == "Dzień dobry."
    assert dictation.inserted == ["Dzień dobry."]
    assert [path.name for path in dictation.runtime.iterdir()] == ["test"]
