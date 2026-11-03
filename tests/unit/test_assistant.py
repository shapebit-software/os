"""desktop/assistant/assistant, against a made-up model server and made-up
system commands: answers stream into conversations that persist, actions ask
as their risk says, requests run one at a time in order, and Stop stops."""

import http.server
import json
import os
import pathlib
import socket
import socketserver
import subprocess
import threading
import time

import pytest

ROOT = pathlib.Path(__file__).parents[2]
ASSISTANT = ROOT / "desktop" / "assistant" / "assistant"

# The system's commands, each logging how it was called. Brightness is 40%.
COMMANDS = {
    "brightnessctl": 'case "$*" in *machine-readable*) echo "intel_backlight,backlight,410,40%,1024";; esac',
    "wpctl": 'case "$1" in get-volume) echo "Volume: 0.40";; esac',
    "nmcli": 'case "$*" in "radio wifi") echo enabled;; *device*) echo "wifi:connected:Home";; esac',
    "bluetoothctl": 'case "$1" in show) echo "	Powered: yes";; esac',
    "systemctl": "true",
    "qs": 'case "$*" in *keyboardLayout*) echo us;; *setKeyboardLayout*) echo true;; *doNotDisturb*) echo false;; esac',
}


class Model:
    """An OpenAI-style chat server that answers from a script: each reply is
    {"text": [...]} or {"calls": [(name, arguments)]}, or {"status": 503};
    "hold" makes it wait until released."""

    def __init__(self, unix=None):
        self.replies = []
        self.requests = []
        self.release = threading.Event()
        outer = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def address_string(self):
                return "local"

            def do_POST(self):
                body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                reply = outer.replies.pop(0) if outer.replies else {"text": ["(nothing scripted)"]}
                if reply.get("status"):
                    if "then" in reply:
                        outer.replies.insert(0, reply["then"])
                    self.send_response(reply["status"])
                    self.send_header("Content-Length", "0")
                    self.end_headers()
                    return
                outer.requests.append(body)
                self.send_response(200)
                self.send_header("Content-Type", "text/event-stream")
                self.end_headers()

                def chunk(delta):
                    self.wfile.write(b"data: " + json.dumps({"choices": [{"delta": delta}]}).encode() + b"\n\n")
                    self.wfile.flush()

                try:
                    for piece in reply.get("text", []):
                        chunk({"content": piece})
                        if reply.get("hold"):
                            outer.release.wait(20)
                    for index, (name, arguments) in enumerate(reply.get("calls", [])):
                        chunk({"tool_calls": [{"index": index, "id": f"c{index}-{len(outer.requests)}",
                                               "function": {"name": name, "arguments": json.dumps(arguments)}}]})  # fmt: skip
                    self.wfile.write(b"data: [DONE]\n\n")
                except OSError:
                    pass

        if unix:
            class Server(socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
                daemon_threads = True

            self.server = Server(str(unix), Handler)
        else:
            self.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    def close(self):
        self.release.set()
        self.server.shutdown()
        self.server.server_close()


class Client:
    def __init__(self, path):
        for _ in range(100):
            try:
                self.socket = socket.socket(socket.AF_UNIX)
                self.socket.connect(str(path))
                break
            except OSError:
                time.sleep(0.05)
        else:
            raise AssertionError("the assistant didn't listen")
        self.socket.settimeout(0.2)
        self.buffer = b""
        self.events = []

    def send(self, **request):
        self.socket.sendall((json.dumps(request) + "\n").encode())

    def wait(self, test, timeout=15):
        """The first event, since the last wait, that passes test."""
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            while self.events:
                event = self.events.pop(0)
                if test(event):
                    return event
            try:
                data = self.socket.recv(65536)
            except socket.timeout:
                continue
            assert data, "the assistant closed the connection"
            self.buffer += data
            while b"\n" in self.buffer:
                line, self.buffer = self.buffer.split(b"\n", 1)
                self.events.append(json.loads(line))
        raise AssertionError("no such event came")

    def ask(self, op, **fields):
        self.send(op=op, **fields)
        return self.wait(lambda e: e["event"] not in ("message", "status", "conversations", "settings"))

    def message(self, test, timeout=15):
        return self.wait(lambda e: e["event"] == "message" and test(e["message"]), timeout)["message"]

    def done(self, timeout=15):
        """The last state of the next reply that ends."""
        return self.message(lambda m: m["role"] == "assistant" and m["state"] in ("done", "failed", "stopped"), timeout)

    def card(self, state, timeout=15):
        return self.message(lambda m: m["role"] == "action" and m.get("state") == state, timeout)


class Setup:
    def __init__(self, tmp_path, model=None, entry=None):
        self.tmp = tmp_path
        bin_dir = tmp_path / "bin"
        bin_dir.mkdir()
        self.log = tmp_path / "commands.log"
        for name, body in COMMANDS.items():
            path = bin_dir / name
            path.write_text(f'#!/bin/bash\necho "{name} $*" >> "{self.log}"\n{body}\n')
            path.chmod(0o755)
        self.model = model or Model()
        catalog = tmp_path / "models.json"
        catalog.write_text(json.dumps([entry or {
            "id": "test", "name": "Test model", "where": "online", "url": f"http://127.0.0.1:{self.model.server.server_address[1]}/v1"}]))  # fmt: skip
        self.socket_path = tmp_path / "assistant.sock"
        self.env = {**os.environ, "PATH": f"{bin_dir}:{os.environ['PATH']}", "ASSISTANT_MODELS": str(catalog),
                    "ASSISTANT_SOCKET": str(self.socket_path), "XDG_RUNTIME_DIR": str(tmp_path),
                    "XDG_DATA_HOME": str(tmp_path / "data"), "XDG_CONFIG_HOME": str(tmp_path / "config"),
                    "XDG_STATE_HOME": str(tmp_path / "state"), "EXTRAS_DIR": str(tmp_path / "extras"),
                    "ASSISTANT_SYSFS": str(tmp_path / "sys"), "ASSISTANT_MODEL_STARTUP": "10", "HOME": str(tmp_path / "home")}  # fmt: skip
        self.env.pop("DESKTOP_SHELL", None)
        (tmp_path / "home").mkdir()
        self.process = None
        self.start()

    def start(self):
        self.socket_path.unlink(missing_ok=True)
        self.process = subprocess.Popen([ASSISTANT, "serve"], env=self.env)
        self.client = Client(self.socket_path)
        self.state = self.client.ask("hello", pid=4242)
        return self.client

    def stop(self):
        self.process.kill()
        self.process.wait()

    def commands(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def settings(self):
        path = self.tmp / "config" / "assistant" / "settings.json"
        return json.loads(path.read_text()) if path.exists() else {"grants": []}


@pytest.fixture
def setup(tmp_path):
    made = Setup(tmp_path)
    yield made
    made.stop()
    made.model.close()


def test_an_answer_streams_into_a_conversation_that_persists(setup):
    setup.model.replies.append({"text": ["Paris ", "is the capital."]})
    sent = setup.client.ask("send", id=None, text="What is the capital of France?", workspace="2")
    reply = setup.client.done()
    assert reply["state"] == "done" and reply["text"] == "Paris is the capital."
    request = setup.model.requests[0]
    assert request["stream"] is True and request["messages"][0]["role"] == "system"
    assert request["messages"][1:] == [{"role": "user", "content": "What is the capital of France?"}]
    assert {t["function"]["name"] for t in request["tools"]} >= {"set_brightness", "get_status", "power_off"}
    setup.stop()
    client = setup.start()
    assert setup.state["conversations"][0]["title"] == "What is the capital of France?"
    assert setup.state["conversations"][0]["workspace"] == "2"
    conversation = client.ask("open", id=sent["conversation"])
    assert [m["role"] for m in conversation["messages"]] == ["user", "assistant"]


def test_a_conversation_goes_on_with_what_was_said(setup):
    setup.model.replies += [{"text": ["Hi."]}, {"text": ["Again."]}]
    sent = setup.client.ask("send", id=None, text="Hello")
    setup.client.done()
    setup.client.send(op="send", id=sent["conversation"], text="And again")
    setup.client.done()
    assert [(m["role"], m["content"]) for m in setup.model.requests[1]["messages"][1:]] == [
        ("user", "Hello"), ("assistant", "Hi."), ("user", "And again")]


def test_reading_runs_at_once_and_the_model_hears_the_result(setup):
    setup.model.replies += [{"calls": [("get_status", {})]}, {"text": ["Wi-Fi is on."]}]
    setup.client.send(op="send", id=None, text="is wifi on?")
    card = setup.client.card("done")
    assert card["risk"] == "read" and "wifi: on" in card["result"]
    assert setup.client.done()["text"] == "Wi-Fi is on."
    tool = setup.model.requests[1]["messages"][-1]
    assert tool["role"] == "tool" and "wifi: on" in tool["content"]


def test_a_change_is_proposed_and_applied_once(setup):
    setup.model.replies += [{"calls": [("set_brightness", {"percent": 50})]}, {"text": ["Done."]}]
    setup.client.send(op="send", id=None, text="brightness 50")
    card = setup.client.card("proposed")
    assert card["title"] == "Set brightness to 50%" and card["group"] == "settings"
    assert not any("set" in c for c in setup.commands() if c.startswith("brightnessctl"))
    setup.client.send(op="answer", card=card["id"], choice="apply")
    assert setup.client.card("done")["undoable"] is True
    setup.client.done()
    assert "brightnessctl --class=backlight set 50%" in setup.commands()
    # Applying once allows nothing more.
    setup.model.replies += [{"calls": [("set_brightness", {"percent": 60})]}, {"text": ["Done."]}]
    setup.client.send(op="send", id=None, text="brightness 60")
    setup.client.card("proposed")


def test_a_group_allowed_always_runs_until_revoked(setup):
    setup.model.replies += [{"calls": [("set_volume", {"percent": 30})]}, {"text": ["Done."]}]
    setup.client.send(op="send", id=None, text="volume 30")
    setup.client.send(op="answer", card=setup.client.card("proposed")["id"], choice="always")
    setup.client.done()
    assert setup.settings()["grants"] == ["settings"]
    setup.model.replies += [{"calls": [("set_mute", {"device": "microphone", "muted": True})]}, {"text": ["Muted."]}]
    setup.client.send(op="send", id=None, text="mute the mic")
    setup.client.card("done")
    assert "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 1" in setup.commands()
    setup.client.done()
    setup.client.send(op="grant", group="connections")
    setup.client.wait(lambda e: e["event"] == "settings" and e["grants"] == ["settings", "connections"])
    setup.client.send(op="grant", group="anything")
    setup.client.send(op="revoke", group="settings")
    setup.client.wait(lambda e: e["event"] == "settings" and e["grants"] == ["connections"])
    setup.model.replies += [{"calls": [("set_volume", {"percent": 20})]}, {"text": ["Done."]}]
    setup.client.send(op="send", id=None, text="volume 20")
    setup.client.card("proposed")
    activity = [json.loads(line)["kind"] for line in (setup.tmp / "state/assistant/activity.jsonl").read_text().splitlines()]
    assert activity[:3] == ["grant", "done", "done"] and "revoke" in activity


def test_what_is_destructive_asks_every_time_and_can_be_declined(setup):
    setup.model.replies += [{"calls": [("power_off", {})]}, {"text": ["Okay, I won't."]}]
    setup.client.send(op="send", id=None, text="shut down")
    card = setup.client.card("proposed")
    assert card["risk"] == "confirm" and card["group"] is None
    setup.client.send(op="answer", card=card["id"], choice="always")
    setup.client.card("done")
    setup.client.done()
    assert setup.settings()["grants"] == []
    # Declined, the model isn't asked again: it might say it was done.
    setup.model.replies += [{"calls": [("power_off", {})]}]
    setup.client.send(op="send", id=None, text="shut down")
    setup.client.send(op="answer", card=setup.client.card("proposed")["id"], choice="decline")
    assert setup.client.card("declined")
    setup.client.wait(lambda e: e["event"] == "status" and not e["busy"])
    assert setup.commands().count("systemctl poweroff") == 1
    assert len(setup.model.requests) == 3
    # The next request tells the model it wasn't done.
    setup.model.replies.append({"text": ["Okay."]})
    setup.client.send(op="send", id=setup.client.ask("search", query="")["ids"][0], text="why?")
    setup.client.done()
    assert "NOT DONE: the person declined" in str(setup.model.requests[-1]["messages"])


def test_a_change_can_be_undone(setup):
    setup.model.replies += [{"calls": [("set_brightness", {"percent": 90})]}, {"text": ["Done."]}]
    setup.client.send(op="send", id=None, text="brighter")
    setup.client.send(op="answer", card=setup.client.card("proposed")["id"], choice="apply")
    card = setup.client.card("done")
    setup.client.done()
    setup.client.send(op="undo", card=card["id"])
    assert setup.client.card("undone")
    assert setup.commands()[-1] == "brightnessctl --class=backlight set 40%"


def test_wrong_calls_fail_and_the_model_hears_why(setup):
    setup.model.replies += [{"calls": [("set_brightness", {"percent": 150}), ("format_disk", {})]}, {"text": ["Sorry."]}]
    setup.client.send(op="send", id=None, text="brightness 150")
    assert "from 0 to 100" in setup.client.card("failed")["error"]
    assert "no tool format_disk" in setup.client.card("failed")["error"]
    setup.client.done()
    told = [m["content"] for m in setup.model.requests[1]["messages"] if m["role"] == "tool"]
    assert len(told) == 2 and all(t.startswith("NOT DONE, it failed:") for t in told)


def test_requests_run_in_order_and_replies_follow_their_own(setup):
    setup.model.replies += [{"text": ["first ", "answer"], "hold": True}, {"text": ["second answer"]}]
    sent = setup.client.ask("send", id=None, text="one")
    setup.client.message(lambda m: m["role"] == "assistant" and m["state"] == "answering")
    setup.client.send(op="send", id=sent["conversation"], text="two")
    status = setup.client.wait(lambda e: e["event"] == "status" and e["queued"] == 1)
    assert status["busy"]
    setup.model.release.set()
    assert setup.client.done()["text"] == "first answer"
    assert setup.client.done()["text"] == "second answer"
    listed = setup.client.ask("open", id=sent["conversation"])["messages"]
    assert [(m["role"], m["text"]) for m in listed] == [
        ("user", "one"), ("assistant", "first answer"), ("user", "two"), ("assistant", "second answer")]


def test_stop_ends_the_request_and_the_queue_goes_on(setup):
    setup.model.replies += [{"calls": [("set_wifi", {"enabled": False})]}, {"text": ["next"]}]
    sent = setup.client.ask("send", id=None, text="wifi off")
    setup.client.card("proposed")
    setup.client.send(op="send", id=sent["conversation"], text="then this")
    setup.client.send(op="stop")
    assert setup.client.card("cancelled")
    assert setup.client.done()["text"] == "next"
    assert not any(c.startswith("nmcli radio wifi off") for c in setup.commands())


def test_stop_while_answering(setup):
    setup.model.replies += [{"text": ["a ", "long ", "answer"], "hold": True}]
    setup.client.send(op="send", id=None, text="tell me")
    setup.client.message(lambda m: m["role"] == "assistant" and m["state"] == "answering")
    setup.client.send(op="stop")
    reply = setup.client.done()
    assert reply["state"] == "stopped" and reply["text"].startswith("a ")


def test_while_locked_nothing_new_starts(setup):
    setup.client.send(op="locked", locked=True)
    setup.model.replies.append({"text": ["later"]})
    setup.client.send(op="send", id=None, text="hello")
    with pytest.raises(AssertionError):
        setup.client.done(timeout=1)
    setup.client.send(op="locked", locked=False)
    assert setup.client.done()["text"] == "later"


def test_conversations_are_searched_deleted_and_restored(setup):
    setup.model.replies += [{"text": ["Use a firewall."]}, {"text": ["Bake it."]}]
    first = setup.client.ask("send", id=None, text="network safety")
    setup.client.done()
    second = setup.client.ask("send", id=None, text="a cake")
    setup.client.done()
    assert setup.client.ask("search", query="FIREWALL")["ids"] == [first["conversation"]]
    assert setup.client.ask("search", query="")["ids"] == [second["conversation"], first["conversation"]]
    setup.client.send(op="rename", id=second["conversation"], title="Baking")
    assert setup.client.wait(lambda e: e["event"] == "conversations")["conversations"][0]["title"] == "Baking"
    setup.client.send(op="delete", id=first["conversation"])
    setup.client.wait(lambda e: e["event"] == "deleted" and e["id"] == first["conversation"])
    assert setup.client.ask("search", query="firewall")["ids"] == []
    setup.client.send(op="restore", id=first["conversation"])
    assert setup.client.ask("search", query="firewall")["ids"] == [first["conversation"]]


def test_a_missing_model_says_so(tmp_path):
    entry = {"id": "local", "name": "Local", "where": "local", "extra": "absent"}
    made = Setup(tmp_path, entry=entry)
    try:
        assert made.state["model"]["ready"] is False
        made.client.send(op="send", id=None, text="hello")
        assert "No model is installed" in made.client.done()["error"]
    finally:
        made.stop()
        made.model.close()


def test_an_unreachable_model_says_so(tmp_path):
    model = Model()
    port = model.server.server_address[1]
    model.close()
    made = Setup(tmp_path, model=Model(), entry={"id": "gone", "name": "Gone", "where": "online", "url": f"http://127.0.0.1:{port}/v1"})
    try:
        made.client.send(op="send", id=None, text="hello")
        assert made.client.done()["error"] == "Couldn't reach Gone."
    finally:
        made.stop()
        made.model.close()


def test_a_local_model_is_waited_for_while_it_loads(tmp_path):
    path = tmp_path / "model.sock"
    model = Model(unix=path)
    model.replies.append({"status": 503, "then": {"status": 503, "then": {"text": ["Ready."]}}})
    (tmp_path / "extras" / "gemma").mkdir(parents=True)
    (tmp_path / "extras" / "gemma" / "model.gguf").write_bytes(b"")
    made = Setup(tmp_path, model=model, entry={"id": "gemma", "name": "Gemma", "where": "local", "extra": "gemma", "socket": str(path)})
    try:
        assert made.state["model"]["ready"] is True
        made.client.send(op="send", id=None, text="hello")
        assert made.client.message(lambda m: m["role"] == "assistant" and m["state"] == "starting")
        assert made.client.done()["text"] == "Ready."
    finally:
        made.stop()
        model.close()
