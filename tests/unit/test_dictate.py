"""desktop/dictation/dictate, with a made-up compositor, window, clipboard, and
dictation/hear, which tests/unit/test_hear.py covers. Every path says where the
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
# Files in FAKES make it fail before it listens ("cannot-hear") or after the stop
# ("fails"), say a draft ("draft"), stop by itself ("gives-up", once "give-up" is
# there), or wait for "go" before the words ("waits").
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
    say(state="failed")
    sys.exit(1)
say(state="listening", level=1, quiet=False, idle=False)
if mark("draft"):
    say(state="draft", text=mark("draft"), tail="")
def write_down():
    say(state="writing")
    while (fakes / "waits").exists() and not (fakes / "go").exists():
        time.sleep(0.02)
    if (fakes / "fails").exists():
        say(state="failed")
        sys.exit(1)
    said = mark("said")
    if said:
        say(state="done", text=said)
    else:
        say(state="nothing")
    sys.exit(0)
if (fakes / "gives-up").exists():
    while not (fakes / "give-up").exists():
        time.sleep(0.02)
    write_down()
for line in sys.stdin:
    what = json.loads(line)["do"]
    if what == "discard":
        sys.exit(130)
    if what == "stop":
        write_down()
sys.exit(130)
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
    """As much of a compositor, and of the application with the field, as an input
    method sees. A field that tells its text tells it again after each change.
    "draft" is what the field shows of the input method's draft, and "drafts"
    each one it showed."""

    def __init__(self, path, available=True):
        self.available = available
        self.commits = []
        self.draft = ""
        self.drafts = []
        self.before = ""
        self.tells = True
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
        draft = None
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
                elif target == METHOD and opcode == 1:
                    size = struct.unpack_from("<I", payload)[0]
                    draft = payload[4 : 3 + size].decode()
                elif target == METHOD and opcode == 3:
                    # A commit with no draft of its own leaves none.
                    if (draft or "") != self.draft:
                        self.draft = draft or ""
                        self.drafts.append(self.draft)
                    if pending is not None:
                        self.commits.append(pending)
                        self.before += pending
                    pending = draft = None
                    self.told()

    def told(self):
        if self.tells:
            cursor = len(self.before.encode())
            self.event(METHOD, 2, wl_string(self.before) + struct.pack("<II", cursor, cursor))
            self.event(METHOD, 5)

    def focus_field(self, before="", purpose=0, hint=0, selected=False, tells=True):
        self.method_bound.wait(5)
        # A field just focused shows no draft.
        self.before, self.tells, self.draft = before, tells, ""
        cursor = len(before.encode())
        self.event(METHOD, 0)
        if tells:
            self.event(METHOD, 2, wl_string(before) + struct.pack("<II", cursor, 0 if selected else cursor))
        self.event(METHOD, 4, struct.pack("<II", hint, purpose))
        self.event(METHOD, 5)



class Dictation:
    def __init__(self, tmp_path, *args, said="", window=BROWSER, compositor=True, available=True, draft="",
                 waits=False, fails=False, hears=True, gives_up=False, real_hear=False, env=None):  # fmt: skip
        self.fakes = tmp_path / "fakes"
        self.runtime = tmp_path / "runtime"
        self.fakes.mkdir()
        self.runtime.mkdir()
        self.said(said)
        self.window(window)
        (self.fakes / "draft").write_text(draft)
        for name, present in (("waits", waits), ("cannot-hear", not hears), ("gives-up", gives_up), ("fails", fails)):
            if present:
                (self.fakes / name).touch()
        for name, script in (("hear", HEAR), ("wl-copy", CLIPBOARD), ("hyprctl", WINDOW)):
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
            [DICTATE, *args],
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

    def said(self, text):
        (self.fakes / "said").write_text(text)

    def window(self, window):
        (self.fakes / "window").write_text(json.dumps(window))

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
    def copied(self):
        return self.file("copied")

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


def eventually(check):
    """The compositor's side comes a moment after what dictate says."""
    deadline = time.monotonic() + 5
    while not check():
        assert time.monotonic() < deadline
        time.sleep(0.02)


@pytest.fixture
def dictate(tmp_path):
    started = []

    def start(*args, **kwargs):
        started.append(Dictation(tmp_path, *args, **kwargs))
        return started[-1]

    yield start
    for dictation in started:
        dictation.process.kill()
        dictation.process.wait()


# A field that stays: straight in ---------------------------------------------


def test_text_goes_straight_into_the_field_and_is_copied(dictate):
    dictation = dictate("--copy", said="Dzień dobry, wszystkim.")
    dictation.compositor.focus_field()
    dictation.say()
    message = dictation.wait_for("done")
    assert (message["text"], message["inserted"], message["copied"], message["app"]) == (
        "Dzień dobry, wszystkim.", True, True, "firefox")
    assert dictation.ended() == 0
    assert dictation.inserted == ["Dzień dobry, wszystkim."]
    assert dictation.copied == "Dzień dobry, wszystkim."


def test_it_hears_with_hear(dictate):
    dictation = dictate()
    dictation.say()
    dictation.wait_for("nothing")
    assert dictation.file("hear-runs") == "\n"


def test_without_copy_it_only_inserts(dictate):
    dictation = dictate(said="Hello")
    dictation.compositor.focus_field()
    dictation.say()
    assert dictation.wait_for("done", inserted=True, copied=False)
    assert dictation.copied is None


def test_only_copy_never_inserts(dictate):
    dictation = dictate("--only-copy", said="Hello")
    dictation.compositor.focus_field()
    dictation.say()
    assert dictation.wait_for("done", inserted=False, copied=True)
    assert dictation.ended() == 0
    assert dictation.inserted == []
    assert dictation.copied == "Hello"


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
    assert dictation.wait_for("done")["text"] == "there"
    assert dictation.inserted == [expected]


def test_moving_to_a_field_before_the_stop_is_where_it_goes(dictate):
    dictation = dictate(said="Hello")
    dictation.compositor.focus_field()
    dictation.wait_for("listening")
    dictation.window(OTHER)
    dictation.compositor.focus_field()
    time.sleep(0.2)
    dictation.do("stop")
    assert dictation.wait_for("done")["app"] == "chat"
    assert dictation.inserted == ["Hello"]


def test_where_it_stopped_by_itself_is_where_it_goes(dictate):
    dictation = dictate(said="Hello", gives_up=True)
    dictation.compositor.focus_field()
    time.sleep(0.2)
    (dictation.fakes / "give-up").touch()
    dictation.wait_for("done", inserted=True)
    assert dictation.inserted == ["Hello"]


# Moved while it was written down, or no field: only copied -------------------


def test_another_window_while_writing_gets_nothing(dictate):
    dictation = dictate("--copy", waits=True, said="Private")
    dictation.compositor.focus_field()
    dictation.writing()
    dictation.window(OTHER)
    dictation.compositor.focus_field()
    time.sleep(0.2)
    dictation.go()
    assert dictation.wait_for("done", inserted=False, copied=True)
    assert dictation.inserted == []
    assert dictation.copied == "Private"


def test_another_field_in_the_same_window_while_writing_gets_nothing(dictate):
    dictation = dictate("--copy", waits=True, said="Private")
    dictation.compositor.focus_field()
    dictation.writing()
    dictation.compositor.focus_field()
    time.sleep(0.2)
    dictation.go()
    dictation.wait_for("done", inserted=False)
    assert dictation.inserted == []


def test_a_field_that_appears_only_after_the_stop_gets_nothing(dictate):
    dictation = dictate("--copy", waits=True, said="Hello")
    dictation.writing()
    dictation.compositor.focus_field()
    time.sleep(0.2)
    dictation.go()
    dictation.wait_for("done", inserted=False)
    assert dictation.inserted == []


def test_a_window_left_after_the_stop_gets_nothing(dictate):
    dictation = dictate("--copy", waits=True, said="Tajne.")
    dictation.compositor.focus_field()
    dictation.writing()
    dictation.window(OTHER)
    dictation.go()
    dictation.wait_for("done", inserted=False)
    assert dictation.inserted == []


def test_with_no_field_it_is_copied(dictate):
    dictation = dictate("--copy", said="Hello")
    dictation.say()
    message = dictation.wait_for("done")
    assert (message["inserted"], message["copied"], message["app"]) == (False, True, "firefox")
    assert dictation.ended() == 0
    assert dictation.copied == "Hello"


def test_with_no_field_and_no_copy_the_text_is_only_in_the_answer(dictate):
    dictation = dictate(said="Hello")
    dictation.say()
    assert dictation.wait_for("done", inserted=False, copied=False)["text"] == "Hello"
    assert dictation.copied is None


@pytest.mark.parametrize(
    "conditions",
    [
        {"window": {"address": "0xc", "class": "old", "xwayland": True}},
        {"compositor": False},
        {"available": False},
    ],
    ids=["xwayland", "no compositor", "another input method"],
)
def test_where_fields_are_not_told_nothing_is_inserted(dictate, conditions):
    dictation = dictate("--copy", said="Hello", **conditions)
    dictation.say()
    dictation.wait_for("done", inserted=False, copied=True)
    assert dictation.inserted == []


@pytest.mark.parametrize("purpose, hint", [(8, 0), (9, 0), (0, 0x40)])
def test_a_secret_field_never_gets_it(dictate, purpose, hint):
    dictation = dictate("--copy", said="Hello")
    dictation.compositor.focus_field(purpose=purpose, hint=hint)
    dictation.say()
    dictation.wait_for("done", inserted=False, copied=True)
    assert dictation.inserted == []


# While it listens ---------------------------------------------------------------


def test_what_hear_says_while_listening_goes_to_the_shell_and_is_not_inserted(dictate):
    dictation = dictate("--copy", said="Dzień dobry.", draft="Dzień")
    dictation.compositor.focus_field()
    assert dictation.wait_for("listening")["level"] == 1
    assert dictation.wait_for("draft", inline=True)["text"] == "Dzień"
    assert dictation.inserted == []
    assert dictation.copied is None


def test_the_draft_shows_in_the_field_where_it_would_go_then_the_text_takes_its_place(dictate):
    dictation = dictate("--copy", said="świat", draft="świ")
    dictation.compositor.focus_field(before="Witaj")
    dictation.wait_for("draft", inline=True)
    eventually(lambda: dictation.compositor.draft == " świ")
    dictation.do("stop")
    dictation.wait_for("done", inserted=True)
    assert dictation.inserted == [" świat"]
    assert dictation.compositor.draft == ""


def test_the_draft_follows_the_focus_while_listening(dictate):
    dictation = dictate("--copy", said="Hello", draft="Hel")
    dictation.wait_for("draft", inline=False)
    assert dictation.compositor.drafts == []
    dictation.compositor.focus_field()
    dictation.wait_for("draft", inline=True)
    eventually(lambda: dictation.compositor.draft == "Hel")


@pytest.mark.parametrize(
    "args, field",
    [(["--only-copy"], {}), (["--copy"], {"purpose": 8})],
    ids=["only copy", "password"],
)
def test_no_draft_where_the_words_may_not_go(dictate, args, field):
    dictation = dictate(*args, said="Hello", draft="Hel")
    dictation.compositor.focus_field(**field)
    dictation.wait_for("listening")
    time.sleep(0.3)
    assert dictation.wait_for("draft")["inline"] is False
    assert dictation.compositor.drafts == []


def test_after_the_stop_another_field_shows_no_draft_and_the_last_one_drops_it(dictate):
    dictation = dictate("--copy", waits=True, said="Private", draft="Priv")
    dictation.compositor.focus_field()
    dictation.wait_for("draft", inline=True)
    dictation.do("stop")
    dictation.wait_for("writing")
    dictation.window(OTHER)
    dictation.compositor.focus_field()
    dictation.wait_for("draft", inline=False)
    assert dictation.compositor.draft == ""
    dictation.go()
    dictation.wait_for("done", inserted=False)
    assert dictation.compositor.drafts == ["Priv"]


def test_a_draft_not_inserted_is_taken_away(dictate):
    dictation = dictate("--copy", waits=True, said="Private", draft="Priv")
    dictation.compositor.focus_field()
    dictation.wait_for("draft", inline=True)
    dictation.do("stop")
    dictation.wait_for("writing")
    dictation.window(OTHER)
    dictation.go()
    dictation.wait_for("done", inserted=False)
    eventually(lambda: dictation.compositor.drafts == ["Priv", ""])


def test_nothing_said_delivers_nothing_and_says_so(dictate):
    dictation = dictate("--copy")
    dictation.compositor.focus_field()
    dictation.say()
    dictation.wait_for("nothing")
    assert dictation.ended() == 0
    assert dictation.inserted == []
    assert dictation.copied is None


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
    dictation = dictate("--copy", said="Secret")
    dictation.compositor.focus_field()
    dictation.wait_for("listening")
    discard(dictation)
    assert dictation.ended() == 130
    assert dictation.hearing_gone
    assert dictation.inserted == []
    assert dictation.copied is None


def test_discarding_takes_the_draft_away(dictate):
    dictation = dictate("--copy", said="Secret", draft="Sec")
    dictation.compositor.focus_field()
    dictation.wait_for("draft", inline=True)
    dictation.do("discard")
    assert dictation.ended() == 130
    eventually(lambda: dictation.compositor.drafts == ["Sec", ""])
    assert dictation.inserted == []


def test_discarding_while_writing_it_down_delivers_nothing(dictate):
    dictation = dictate("--copy", waits=True, said="Secret")
    dictation.compositor.focus_field()
    dictation.writing()
    dictation.do("discard")
    assert dictation.ended() == 130
    assert dictation.hearing_gone
    assert dictation.inserted == []
    assert dictation.copied is None


# Failing ------------------------------------------------------------------------


def test_when_it_cannot_hear_it_fails(dictate):
    dictation = dictate("--copy", hears=False)
    dictation.wait_for("failed")
    assert dictation.ended() == 1


def test_when_it_cannot_write_it_down_it_fails(dictate):
    dictation = dictate("--copy", fails=True, said="Lost")
    dictation.compositor.focus_field()
    dictation.say()
    dictation.wait_for("failed")
    assert dictation.ended() == 1
    assert dictation.inserted == []


# With the real hear ---------------------------------------------------------------


def test_with_the_real_hear_the_words_go_into_the_field_and_no_audio_stays(dictate):
    dictation = dictate(said="Dzień dobry.\n", real_hear=True)
    dictation.compositor.focus_field()
    dictation.wait_for("listening", level=1)
    dictation.do("stop")
    assert dictation.wait_for("done")["text"] == "Dzień dobry."
    assert dictation.inserted == ["Dzień dobry."]
    assert [path.name for path in dictation.runtime.iterdir()] == ["test"]
