"""The language models the assistant can use, and how it talks to them.

A model speaks one of three chat APIs, each streamed and with tools: "chat",
OpenAI's /chat/completions, which llama-server and OpenAI offer;
"anthropic", Claude's /messages; and "responses", OpenAI's /responses, which
a ChatGPT plan answers on. The assistant hands every one the conversation as
the chat API has it, and each adapter here turns it into its own. So a new
model, on this computer or online, is one entry in a catalog:

- models.json beside this file, from the OS: the local models, each an extra
  (desktop/extras), run by llama-server on demand (language-model@.socket).
- $XDG_CONFIG_HOME/assistant/models.json: the person's own, the online ones
  that Settings > Assistant > Models adds (providers.py). Their key, or the
  ChatGPT sign-in, is in the keyring, never in a file.

An entry: {"id", "name", "mark": one letter, "color": "#rrggbb",
"where": "local" or "online", "extra": the extra that holds model.gguf (local),
"provider": an online provider's id (providers.py), "api": "chat",
"anthropic", or "responses" ("chat" if none), "url": the API's base, such as
https://api.example.com/v1 (online), "model": the name the API knows it by,
"key": true if it needs an API key kept for the model itself, "options": what
else every request sends, such as {"temperature": 0.2}, "prompt": what the
model needs told beyond the assistant's own prompt, "vision": true if it
reads pictures (online)}.

A local model reads pictures once the extra of its vision projector, its own
extra's id with "-vision", holds mmproj.gguf; llama-server@.service loads it.
"""

import http.client
import json
import os
import pathlib
import socket
import subprocess
import time
import urllib.parse

import chatgpt
import providers

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
    for own, found in ((False, _read(VENDOR)), (True, _read(config_dir() / "models.json"))):
        for entry in found:
            if isinstance(entry, dict) and entry.get("id"):
                if entry.get("provider") and entry["provider"] not in providers.PROVIDERS:
                    continue
                entries[entry["id"]] = {**entry, "own": own}
    return list(entries.values())


def save_own(entries):
    """The person's catalog, written whole."""
    path = config_dir() / "models.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    partial = path.with_suffix(".partial")
    partial.write_text(json.dumps([{k: v for k, v in e.items() if k != "own"} for e in entries], indent=2, ensure_ascii=False))
    os.replace(partial, path)


def own():
    return [e for e in _read(config_dir() / "models.json") if isinstance(e, dict) and e.get("id")]


def ready(entry):
    if entry.get("where") == "local":
        return (EXTRAS / entry["extra"] / "model.gguf").is_file()
    return bool(entry.get("url"))


def sees(entry):
    """Whether the model reads pictures."""
    if entry.get("where") == "local":
        return (EXTRAS / f"{entry['extra']}-vision" / "mmproj.gguf").is_file()
    return entry.get("vision") is True


def describe(entry):
    """What the shell shows of a model."""
    return {
        "id": entry["id"], "name": entry.get("name", entry["id"]), "mark": entry.get("mark", entry.get("name", "?")[:1]),
        "color": entry.get("color", "#6b6f80"), "where": entry.get("where", "online"), "extra": entry.get("extra"),
        "ready": ready(entry), "sees": sees(entry), "provider": entry.get("provider"), "model": entry.get("model"),
        "own": entry.get("own", False),
    }  # fmt: skip


def _key(entry):
    """The credential an online model is asked with, or None."""
    if entry.get("provider") and entry["provider"] not in providers.PROVIDERS:
        raise Unavailable("This provider is not supported.")
    if entry.get("provider") == "chatgpt":
        try:
            return chatgpt.access_token()
        except chatgpt.Failed as error:
            raise Unavailable(str(error)) from None
    if entry.get("provider") in providers.PROVIDERS:
        found = providers.secret(entry["provider"])
        if not found:
            raise Unavailable(f"{entry.get('name', entry['id'])} needs its API key; add it again in Settings > Assistant > Models.")
        return found
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

    def _connect(self, endpoint):
        entry = self.entry
        if entry.get("where") == "local":
            return _UnixConnection(local_socket(entry), TIMEOUT), "/v1" + endpoint
        url = urllib.parse.urlsplit(entry["url"].rstrip("/") + endpoint)
        kind = http.client.HTTPSConnection if url.scheme == "https" else http.client.HTTPConnection
        return kind(url.netloc, timeout=TIMEOUT), url.path

    def _open(self, body, on_status, endpoint="/chat/completions"):
        """Posts the request; a local model still starting is waited for."""
        headers = {"Content-Type": "application/json", "Accept": "text/event-stream"}
        key = _key(self.entry)
        if key and self.entry.get("api") == "anthropic":
            headers.update({"x-api-key": key, "anthropic-version": providers.ANTHROPIC_VERSION})
        elif key:
            headers["Authorization"] = f"Bearer {key}"
        local = self.entry.get("where") == "local"
        deadline = time.monotonic() + STARTUP
        told = False
        while True:
            if self.stopped:
                raise Cancelled()
            try:
                self.connection, path = self._connect(endpoint)
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
                code = ""
                try:
                    said = json.loads(detail)
                except ValueError:
                    said = None
                error = said.get("error", said) if isinstance(said, dict) else None
                if isinstance(error, dict):
                    code = error.get("code") or error.get("type") or ""
                    detail = error.get("message") or error.get("detail") or detail
                elif isinstance(error, str):
                    detail = error
                if str(code).startswith(("subscription_sharing", "chatpass")):
                    raise Unavailable(plan_error(str(code), detail))
                if reply.status in (401, 403):
                    raise Unavailable(f"{self.entry.get('name')} refused the API key, or the sign-in.")
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

    def run(self, messages, tools, on_text, on_status=lambda status: None, options=None):
        """Streams the answer: its text to on_text as it comes; returns the whole
        text and the tool calls, each {"id", "name", "arguments": text}. options
        go over the model's own, for this request."""
        api = self.entry.get("api", "chat")
        endpoint, body = BUILD[api](self.entry, messages, tools, {**self.entry.get("options", {}), **(options or {})})
        if self.entry.get("model"):
            body["model"] = self.entry["model"]
        reply = self._open(json.dumps(body).encode(), on_status, endpoint)
        on_status("answering")
        reading = READ[api](self.entry.get("name", "The model"), on_text)
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
                if reading.feed(chunk):
                    break
        except (OSError, http.client.HTTPException):
            if self.stopped:
                raise Cancelled() from None
            raise Unavailable(f"The connection to {self.entry.get('name')} was lost.") from None
        finally:
            self.connection.close()
        if self.stopped:
            raise Cancelled()
        reading.check()
        result = [reading.calls[index] for index in sorted(reading.calls)]
        for number, call in enumerate(result):
            call["id"] = call["id"] or f"call-{number}"
            call["arguments"] = call["arguments"] or "{}"
        return "".join(reading.text), result


def plan_error(code, detail):
    """What a ChatGPT plan's refusal means for people."""
    if code == "subscription_sharing_usage_limit_exceeded":
        return "Your ChatGPT plan's usage limit is reached for now. See how much is left at chatgpt.com/settings/usage."
    if code in ("subscription_sharing_user_not_eligible", "subscription_sharing_route_not_supported"):
        return "Your ChatGPT plan can't be used here. Plus and Pro can."
    if code in ("subscription_sharing_usage_unavailable", "subscription_sharing_user_unavailable"):
        return "ChatGPT can't answer on your plan right now; try again in a moment."
    if code in ("subscription_sharing_invalid_user", "chatpass_v2_scope_not_authorized", "chatpass_v2_invalid_authorization_context"):
        return "Sign in to ChatGPT again in Settings > Assistant > Models."
    return f"ChatGPT refused: {detail or code}"[:240]


# What each API is sent: (its endpoint, the request), from the conversation
# as the chat API has it: system, user (text, or parts with pictures),
# assistant (with tool_calls), and tool messages.


def build_chat(entry, messages, tools, options):
    body = {"messages": messages, "stream": True, **options}
    if tools:
        body["tools"] = tools
    return "/chat/completions", body


def pictures(content):
    """[("text", text) or ("image", data URL)] of a message's content."""
    if isinstance(content, str):
        return [("text", content)] if content else []
    return [("image", p["image_url"]["url"]) if p.get("type") == "image_url" else ("text", p.get("text", "")) for p in content]


def build_anthropic(entry, messages, tools, options):
    turns = []

    def add(role, blocks):
        if not blocks:
            return
        if turns and turns[-1]["role"] == role:
            turns[-1]["content"] += blocks
        else:
            turns.append({"role": role, "content": blocks})

    for message in messages:
        if message["role"] == "user":
            blocks = []
            for kind, value in pictures(message["content"]):
                if kind == "text" and value:
                    blocks.append({"type": "text", "text": value})
                elif kind == "image":
                    media, _, data = value.removeprefix("data:").partition(";base64,")
                    blocks.append({"type": "image", "source": {"type": "base64", "media_type": media, "data": data}})
            add("user", blocks)
        elif message["role"] == "assistant":
            blocks = [{"type": "text", "text": message["content"]}] if message.get("content") else []
            for call in message.get("tool_calls", []):
                try:
                    arguments = json.loads(call["function"]["arguments"] or "{}")
                except ValueError:
                    arguments = {}
                blocks.append({"type": "tool_use", "id": call["id"], "name": call["function"]["name"], "input": arguments})
            add("assistant", blocks)
        elif message["role"] == "tool":
            add("user", [{"type": "tool_result", "tool_use_id": message["tool_call_id"], "content": message["content"]}])
    body = {"system": "\n\n".join(m["content"] for m in messages if m["role"] == "system"), "messages": turns,
            "max_tokens": 4096, "stream": True}  # fmt: skip
    if "temperature" in options:
        body["temperature"] = min(1.0, options["temperature"])
    if tools:
        body["tools"] = [{"name": t["function"]["name"], "description": t["function"]["description"],
                          "input_schema": t["function"]["parameters"]} for t in tools]  # fmt: skip
    return "/messages", body


def build_responses(entry, messages, tools, options):
    # A ChatGPT plan takes no temperature, nor a system message: the
    # instructions say it.
    items = []
    for message in messages:
        if message["role"] == "user":
            parts = pictures(message["content"])
            if isinstance(message["content"], str):
                items.append({"role": "user", "content": message["content"]})
            else:
                items.append({"role": "user", "content": [{"type": "input_text", "text": v} if k == "text" else
                                                          {"type": "input_image", "image_url": v} for k, v in parts]})  # fmt: skip
        elif message["role"] == "assistant":
            if message.get("content"):
                items.append({"role": "assistant", "content": message["content"]})
            items += [{"type": "function_call", "call_id": c["id"], "name": c["function"]["name"],
                       "arguments": c["function"]["arguments"] or "{}"} for c in message.get("tool_calls", [])]  # fmt: skip
        elif message["role"] == "tool":
            items.append({"type": "function_call_output", "call_id": message["tool_call_id"], "output": message["content"]})
    body = {"instructions": "\n\n".join(m["content"] for m in messages if m["role"] == "system"), "input": items,
            "store": False, "stream": True}  # fmt: skip
    if tools:
        body["tools"] = [{"type": "function", "name": t["function"]["name"], "description": t["function"]["description"],
                          "parameters": t["function"]["parameters"]} for t in tools]  # fmt: skip
    return "/responses", body


BUILD = {"chat": build_chat, "anthropic": build_anthropic, "responses": build_responses}


# How each API's stream is read: feed() takes each event, and says whether
# the answer ended; check() fails an answer that didn't end as it should.


class ReadChat:
    def __init__(self, name, on_text):
        self.name, self.on_text = name, on_text
        self.text, self.calls = [], {}

    def failed(self, message):
        raise Unavailable(f"{self.name} failed: {str(message)[:200]}")

    def feed(self, chunk):
        if "error" in chunk:
            self.failed(chunk["error"].get("message", "") if isinstance(chunk["error"], dict) else chunk["error"])
        for choice in chunk.get("choices") or []:
            delta = choice.get("delta") or {}
            if delta.get("content"):
                self.text.append(delta["content"])
                self.on_text(delta["content"])
            for call in delta.get("tool_calls") or []:
                held = self.calls.setdefault(call.get("index", len(self.calls)), {"id": "", "name": "", "arguments": ""})
                held["id"] = call.get("id") or held["id"]
                function = call.get("function") or {}
                held["name"] += function.get("name") or ""
                held["arguments"] += function.get("arguments") or ""
        return False

    def check(self):
        pass


class ReadAnthropic(ReadChat):
    def __init__(self, name, on_text):
        super().__init__(name, on_text)
        self.ended = False

    def feed(self, chunk):
        kind = chunk.get("type")
        if kind == "error":
            self.failed(chunk.get("error", {}).get("message", ""))
        elif kind == "content_block_start" and chunk["content_block"].get("type") == "tool_use":
            block = chunk["content_block"]
            self.calls[chunk["index"]] = {"id": block["id"], "name": block["name"], "arguments": ""}
        elif kind == "content_block_delta":
            delta = chunk["delta"]
            if delta.get("type") == "text_delta":
                self.text.append(delta["text"])
                self.on_text(delta["text"])
            elif delta.get("type") == "input_json_delta" and chunk["index"] in self.calls:
                self.calls[chunk["index"]]["arguments"] += delta.get("partial_json", "")
        elif kind == "message_stop":
            self.ended = True
            return True
        return False

    def check(self):
        if not self.ended:
            raise Unavailable(f"The connection to {self.name} was lost.")


class ReadResponses(ReadChat):
    def __init__(self, name, on_text):
        super().__init__(name, on_text)
        self.ended = False

    def feed(self, chunk):
        kind = chunk.get("type")
        if kind == "response.output_text.delta":
            self.text.append(chunk["delta"])
            self.on_text(chunk["delta"])
        elif kind == "response.output_item.done" and chunk.get("item", {}).get("type") == "function_call":
            item = chunk["item"]
            self.calls[len(self.calls)] = {"id": item.get("call_id", ""), "name": item["name"], "arguments": item.get("arguments", "")}
        elif kind in ("response.failed", "error"):
            error = chunk.get("response", {}).get("error") or chunk.get("error") or chunk
            code, message = error.get("code") or "", error.get("message") or ""
            raise Unavailable(plan_error(code, message) if str(code).startswith(("subscription_sharing", "chatpass"))
                              else f"{self.name} failed: {message or code}"[:240])  # fmt: skip
        elif kind in ("response.completed", "response.incomplete"):
            self.ended = True
            return True
        return False

    def check(self):
        if not self.ended:
            raise Unavailable(f"The connection to {self.name} was lost.")


READ = {"chat": ReadChat, "anthropic": ReadAnthropic, "responses": ReadResponses}
