"""The language models the assistant can use, and how it talks to them.

Every model speaks the same chat API, OpenAI's /v1/chat/completions with
streaming and tools, which llama-server and most online services offer; so a
new model, on this computer or online, is one entry in a catalog:

- models.json beside this file, from the OS: the local models, each an extra
  (desktop/extras), run by llama-server on demand (language-model@.socket).
- $XDG_CONFIG_HOME/assistant/models.json: the person's own, such as online
  ones. Their API key, if any, is in the keyring (secret-tool), never in a
  file: secret-tool store --label=... assistant-model ID.

An entry: {"id", "name", "mark": one letter, "color": "#rrggbb",
"where": "local" or "online", "extra": the extra that holds model.gguf (local),
"url": the API's base, such as https://api.example.com/v1 (online),
"model": the name the API knows it by, "key": true if it needs an API key,
"options": what else every request sends, such as {"temperature": 0.2}}.
"""

import http.client
import json
import os
import pathlib
import socket
import subprocess
import time
import urllib.parse

HERE = pathlib.Path(__file__).resolve().parent
VENDOR = pathlib.Path(os.environ.get("ASSISTANT_MODELS", HERE / "models.json"))
if not VENDOR.exists():
    VENDOR = pathlib.Path("/usr/share/desktop/assistant/models.json")
EXTRAS = pathlib.Path(os.environ.get("EXTRAS_DIR", "/var/lib/extras"))
RUNTIME = pathlib.Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp"))
# A local model loads for some seconds after its first request; online ones
# answer at once or not at all.
STARTUP = float(os.environ.get("ASSISTANT_MODEL_STARTUP", 120))
TIMEOUT = 300


class Unavailable(Exception):
    """The model can't be reached; the message is for people."""


class Cancelled(Exception):
    pass


def config_dir():
    return pathlib.Path(os.environ.get("XDG_CONFIG_HOME") or pathlib.Path.home() / ".config") / "assistant"


def _read(path):
    try:
        with open(path, encoding="utf-8") as file:
            return json.load(file)
    except (OSError, ValueError):
        return []


def catalog():
    """The OS's models, then the person's; a person's entry replaces one with its id."""
    entries = {}
    for entry in [*_read(VENDOR), *_read(config_dir() / "models.json")]:
        if isinstance(entry, dict) and entry.get("id"):
            entries[entry["id"]] = entry
    return list(entries.values())


def ready(entry):
    if entry.get("where") == "local":
        return (EXTRAS / entry["extra"] / "model.gguf").is_file()
    return bool(entry.get("url"))


def describe(entry):
    """What the shell shows of a model."""
    return {
        "id": entry["id"], "name": entry.get("name", entry["id"]), "mark": entry.get("mark", entry.get("name", "?")[:1]),
        "color": entry.get("color", "#6b6f80"), "where": entry.get("where", "online"), "extra": entry.get("extra"),
        "ready": ready(entry),
    }  # fmt: skip


def _key(entry):
    if not entry.get("key"):
        return None
    try:
        found = subprocess.run(["secret-tool", "lookup", "assistant-model", entry["id"]],
                               capture_output=True, text=True, timeout=10)  # fmt: skip
    except (OSError, subprocess.TimeoutExpired):
        found = None
    if not found or found.returncode != 0 or not found.stdout.strip():
        raise Unavailable(f"{entry.get('name', entry['id'])} needs an API key, and none is saved.")
    return found.stdout.strip()


class _UnixConnection(http.client.HTTPConnection):
    def __init__(self, path, timeout):
        super().__init__("localhost", timeout=timeout)
        self.path = path

    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(self.timeout)
        self.sock.connect(str(self.path))


def local_socket(entry):
    """Where a local model listens; systemd starts the server on the first request."""
    if "socket" in entry:
        return pathlib.Path(entry["socket"])
    path = RUNTIME / f"language-model-{entry['extra']}.sock"
    if not path.exists():
        subprocess.run(["systemctl", "--user", "start", f"language-model@{entry['extra']}.socket"],
                       capture_output=True, timeout=30)  # fmt: skip
    return path


def warm(entry):
    """Has a local model start loading, so that it is there for the request
    that follows: any request at its socket starts its server."""
    if entry.get("where") != "local" or not ready(entry):
        return
    try:
        connection = _UnixConnection(local_socket(entry), 10)
        connection.request("GET", "/health")
        connection.getresponse().read()
        connection.close()
    except (OSError, http.client.HTTPException, subprocess.SubprocessError):
        pass


class Chat:
    """One streamed request; stop() from another thread ends it at once."""

    def __init__(self, entry):
        self.entry = entry
        self.connection = None
        # The connection's socket: http.client lets go of it once a reply that
        # ends the connection begins.
        self.socket = None
        self.stopped = False

    def stop(self):
        self.stopped = True
        if self.socket is not None:
            try:
                self.socket.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass

    def _connect(self):
        entry = self.entry
        if entry.get("where") == "local":
            return _UnixConnection(local_socket(entry), TIMEOUT), "/v1/chat/completions"
        url = urllib.parse.urlsplit(entry["url"].rstrip("/") + "/chat/completions")
        kind = http.client.HTTPSConnection if url.scheme == "https" else http.client.HTTPConnection
        return kind(url.netloc, timeout=TIMEOUT), url.path

    def _open(self, body, on_status):
        """Posts the request; a local model still starting is waited for."""
        headers = {"Content-Type": "application/json", "Accept": "text/event-stream"}
        key = _key(self.entry)
        if key:
            headers["Authorization"] = f"Bearer {key}"
        local = self.entry.get("where") == "local"
        deadline = time.monotonic() + STARTUP
        told = False
        while True:
            if self.stopped:
                raise Cancelled()
            try:
                self.connection, path = self._connect()
                self.connection.request("POST", path, body, headers)
                self.socket = self.connection.sock
                if self.stopped:
                    self.stop()
                reply = self.connection.getresponse()
            except (OSError, http.client.HTTPException):
                reply = None
            if reply is not None and reply.status == 200:
                return reply
            if reply is not None and reply.status != 503:
                detail = reply.read(2000).decode("utf-8", "replace")
                try:
                    detail = json.loads(detail)["error"]["message"]
                except (ValueError, KeyError, TypeError):
                    pass
                if reply.status in (401, 403):
                    raise Unavailable(f"{self.entry.get('name')} refused the API key.")
                raise Unavailable(f"{self.entry.get('name')} answered with an error: {str(detail)[:200]}")
            if not local or time.monotonic() > deadline:
                if self.stopped:
                    raise Cancelled()
                raise Unavailable(f"Couldn't reach {self.entry.get('name')}." if reply is None else
                                  f"{self.entry.get('name')} didn't start in time.")  # fmt: skip
            if not told:
                on_status("starting")
                told = True
            if self.connection is not None:
                self.connection.close()
            time.sleep(0.5)

    def run(self, messages, tools, on_text, on_status=lambda status: None):
        """Streams the answer: its text to on_text as it comes; returns the whole
        text and the tool calls, each {"id", "name", "arguments": text}."""
        body = {"messages": messages, "stream": True, **self.entry.get("options", {})}
        if self.entry.get("model"):
            body["model"] = self.entry["model"]
        if tools:
            body["tools"] = tools
        reply = self._open(json.dumps(body).encode(), on_status)
        on_status("answering")
        text = []
        calls = {}
        try:
            while True:
                line = reply.readline()
                if not line:
                    break
                line = line.strip()
                if not line.startswith(b"data:"):
                    continue
                data = line[5:].strip()
                if data == b"[DONE]":
                    break
                try:
                    chunk = json.loads(data)
                except ValueError:
                    continue
                if "error" in chunk:
                    raise Unavailable(f"{self.entry.get('name')} failed: {chunk['error'].get('message', '')[:200]}")
                for choice in chunk.get("choices") or []:
                    delta = choice.get("delta") or {}
                    if delta.get("content"):
                        text.append(delta["content"])
                        on_text(delta["content"])
                    for call in delta.get("tool_calls") or []:
                        held = calls.setdefault(call.get("index", len(calls)), {"id": "", "name": "", "arguments": ""})
                        held["id"] = call.get("id") or held["id"]
                        function = call.get("function") or {}
                        held["name"] += function.get("name") or ""
                        held["arguments"] += function.get("arguments") or ""
        except (OSError, http.client.HTTPException):
            if self.stopped:
                raise Cancelled() from None
            raise Unavailable(f"The connection to {self.entry.get('name')} was lost.") from None
        finally:
            self.connection.close()
        if self.stopped:
            raise Cancelled()
        result = [calls[index] for index in sorted(calls)]
        for number, call in enumerate(result):
            call["id"] = call["id"] or f"call-{number}"
        return "".join(text), result
