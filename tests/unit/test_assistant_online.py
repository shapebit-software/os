"""Online models (desktop/assistant/providers.py, chatgpt.py, models.py),
against made-up providers: a model is added with an API key, which stays in
the keyring, or by signing in with ChatGPT, whose tokens stay there too; each
API, Claude's and OpenAI's Responses, gets the conversation in its own shape
and streams back text and tool calls; a ChatGPT plan's limits and an ended
sign-in say so; and removing or signing out forgets what was kept."""

import base64
import http.server
import json
import pathlib
import sys
import threading
import time
import urllib.parse
import urllib.request

import pytest

sys.path.insert(0, str(pathlib.Path(__file__).parents[2] / "desktop" / "assistant"))
import models  # noqa: E402
from test_assistant import Setup  # noqa: E402


def jwt(claims):
    part = base64.urlsafe_b64encode(json.dumps(claims).encode()).rstrip(b"=").decode()
    return f"e30.{part}.signature"


class Provider:
    """A made-up provider: Claude's and OpenAI's APIs, and OpenAI's sign-in.
    Each POST answer is from a script: {"text": [...]} or {"calls":
    [(name, arguments)]}, or {"status", "body"}."""

    def __init__(self):
        self.replies = []
        self.requests = []
        self.tokens = []
        self.revoked = []
        self.models = {"anthropic": {"data": [{"id": "claude-test-1", "display_name": "Claude Test"}]},
                       "chatgpt": {"models": [{"slug": "gpt-test", "display_name": "GPT Test", "visibility": "list"},
                                              {"slug": "gpt-hidden", "display_name": "Hidden", "visibility": "hide"}]}}  # fmt: skip
        self.refresh_counter = 0
        outer = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def reply(self, status, body, kind="application/json"):
                data = body if isinstance(body, bytes) else json.dumps(body).encode()
                self.send_response(status)
                self.send_header("Content-Type", kind)
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)

            def do_GET(self):
                if self.path == "/anthropic/v1/models":
                    if self.headers.get("x-api-key") != "sk-ant-good":
                        return self.reply(401, {"error": {"message": "invalid x-api-key"}})
                    return self.reply(200, outer.models["anthropic"])
                if self.path == "/chatgpt/v1/models":
                    if not self.headers.get("Authorization", "").startswith("Bearer access-"):
                        return self.reply(401, {"detail": "no"})
                    return self.reply(200, outer.models["chatgpt"])
                self.reply(404, {})

            def do_POST(self):
                raw = self.rfile.read(int(self.headers["Content-Length"]))
                if self.path.startswith("/auth/"):
                    fields = dict(urllib.parse.parse_qsl(raw.decode()))
                    if self.path == "/auth/api/accounts/oauth/revoke":
                        outer.revoked.append(fields)
                        return self.reply(200, b"", "text/plain")
                    outer.tokens.append(fields)
                    if fields["grant_type"] == "refresh_token" and fields["refresh_token"] == "gone":
                        return self.reply(400, {"error": "refresh_token_expired"})
                    outer.refresh_counter += 1
                    return self.reply(200, {"access_token": f"access-{outer.refresh_counter}", "refresh_token": f"refresh-{outer.refresh_counter}",
                                            "id_token": jwt({"email": "person@example.org"}), "token_type": "Bearer", "expires_in": 3600,
                                            "scope": "openid profile email offline_access resource.invoke chatgpt.tokens.use.direct"})  # fmt: skip
                body = json.loads(raw)
                outer.requests.append((self.path, dict(self.headers), body))
                reply = outer.replies.pop(0) if outer.replies else {"text": ["(nothing scripted)"]}
                if "status" in reply:
                    return self.reply(reply["status"], reply["body"])
                self.send_response(200)
                self.send_header("Content-Type", "text/event-stream")
                self.end_headers()
                for event in (outer.anthropic if self.path.endswith("/messages") else outer.responses)(reply):
                    self.wfile.write(b"data: " + json.dumps(event).encode() + b"\n\n")

        self.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.url = f"http://127.0.0.1:{self.server.server_address[1]}"
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    @staticmethod
    def anthropic(reply):
        yield {"type": "message_start", "message": {}}
        for index, piece in enumerate(reply.get("text", [])):
            yield {"type": "content_block_start", "index": 0, "content_block": {"type": "text", "text": ""}} if index == 0 else {"type": "ping"}
            yield {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": piece}}
        for index, (name, arguments) in enumerate(reply.get("calls", []), start=1):
            yield {"type": "content_block_start", "index": index, "content_block": {"type": "tool_use", "id": f"toolu_{index}", "name": name, "input": {}}}
            text = json.dumps(arguments)
            yield {"type": "content_block_delta", "index": index, "delta": {"type": "input_json_delta", "partial_json": text[:3]}}
            yield {"type": "content_block_delta", "index": index, "delta": {"type": "input_json_delta", "partial_json": text[3:]}}
        yield {"type": "message_stop"}

    @staticmethod
    def responses(reply):
        if "failed" in reply:
            yield {"type": "response.failed", "response": {"error": {"code": reply["failed"], "message": "limit"}}}
            return
        for piece in reply.get("text", []):
            yield {"type": "response.output_text.delta", "delta": piece}
        for index, (name, arguments) in enumerate(reply.get("calls", [])):
            yield {"type": "response.output_item.done",
                   "item": {"type": "function_call", "call_id": f"call_{index}", "name": name, "arguments": json.dumps(arguments)}}  # fmt: skip
        yield {"type": "response.completed", "response": {}}

    def close(self):
        self.server.shutdown()
        self.server.server_close()


@pytest.fixture
def online(tmp_path):
    provider = Provider()
    made = Setup(tmp_path)
    made.env.update(ASSISTANT_ANTHROPIC_URL=f"{provider.url}/anthropic/v1", ASSISTANT_CHATGPT_URL=f"{provider.url}/chatgpt/v1",
                    ASSISTANT_CHATGPT_AUTH=f"{provider.url}/auth")  # fmt: skip
    made.stop()
    made.start()
    made.provider = provider
    yield made
    made.stop()
    made.model.close()
    provider.close()


def keyring(made):
    folder = made.tmp / "keyring"
    return {p.name: p.read_text() for p in folder.iterdir()} if folder.is_dir() else {}


def files_hold(made, text):
    return any(text in p.read_text(errors="replace") for p in made.tmp.rglob("*")
               if p.is_file() and "keyring" not in p.parts and p.suffix in (".json", "", ".jsonl"))  # fmt: skip


def test_a_claude_model_is_added_with_a_key_kept_in_the_keyring_and_answers(online):
    online.client.send(op="provider-models", provider="anthropic", key="sk-ant-bad")
    assert "refused the key" in online.client.wait(lambda e: e["event"] == "provider-models")["error"]
    online.client.send(op="provider-models", provider="anthropic", key="sk-ant-good")
    listed = online.client.wait(lambda e: e["event"] == "provider-models")
    assert listed["models"] == [{"model": "claude-test-1", "name": "Claude Test"}]
    added = online.client.ask("add-model", provider="anthropic", model="claude-test-1", name="Claude Test", key="sk-ant-good")
    assert added == {"event": "model-added", "id": "anthropic:claude-test-1"}
    assert keyring(online) == {"anthropic": "sk-ant-good"} and not files_hold(online, "sk-ant-good")
    state = online.client.ask("hello", pid=4242)
    assert state["model"]["id"] == "anthropic:claude-test-1" and state["model"]["provider"] == "anthropic"

    online.provider.replies += [{"text": ["Let me ", "check."], "calls": [("get_status", {})]}, {"text": ["Wi-Fi is on."]}]
    online.client.send(op="send", id=None, text="is wifi on?")
    online.client.card("done")
    assert online.client.done()["text"] == "Wi-Fi is on."
    (path, headers, first), (_, _, second) = online.provider.requests
    assert path == "/anthropic/v1/messages" and headers["x-api-key"] == "sk-ant-good" and headers["anthropic-version"]
    assert first["model"] == "claude-test-1" and first["stream"] is True and "ShapeBit OS" in first["system"]
    assert first["messages"] == [{"role": "user", "content": [{"type": "text", "text": "is wifi on?"}]}]
    assert {"name", "description", "input_schema"} == set(first["tools"][0])
    # The tool's call and result, in Claude's shape: the result in the person's turn.
    assert second["messages"][1] == {"role": "assistant", "content": [
        {"type": "text", "text": "Let me check."}, {"type": "tool_use", "id": "toolu_1", "name": "get_status", "input": {}}]}
    assert second["messages"][2]["role"] == "user" and second["messages"][2]["content"][0]["type"] == "tool_result"
    assert "wifi: on" in second["messages"][2]["content"][0]["content"]

    online.client.send(op="remove-model", id="anthropic:claude-test-1")
    online.client.wait(lambda e: e["event"] == "settings" and all(m["id"] != "anthropic:claude-test-1" for m in e["models"]))
    assert keyring(online) == {}


def sign_in(made):
    """Continue with ChatGPT, with the test as the browser."""
    url = made.client.ask("chatgpt-sign-in")["url"]
    query = dict(urllib.parse.parse_qsl(urllib.parse.urlsplit(url).query))
    redirect = f"{query['redirect_uri']}?" + urllib.parse.urlencode(
        {"code": "the-code", "state": query["state"], "client_id": "oaiapp_test", "scope": query["scope"]})
    page = urllib.request.urlopen(redirect, timeout=10).read().decode()
    assert "Signed in" in page
    made.client.wait(lambda e: e["event"] == "chatgpt" and e.get("signedIn"))
    return url, query


def test_chatgpt_signs_in_on_openais_page_and_answers_on_the_plan(online):
    url, query = sign_in(online)
    assert url.startswith(f"{online.provider.url}/auth/api/accounts/authorize?")
    assert query["client_id"] == "dynamic_agent_client" and query["agent_name_hint"] == "ShapeBit OS"
    assert query["ext_agent_host_id"].startswith("urn:uuid:") and query["code_challenge_method"] == "S256"
    assert query["redirect_uri"].startswith("http://127.0.0.1:") and query["redirect_uri"].endswith("/auth/callback")
    assert set(query["scope"].split()) >= {"openid", "offline_access", "resource.invoke", "chatgpt.tokens.use.direct"}
    assert query["resource"] == "https://api.openai.com/v1"
    exchange = online.provider.tokens[0]
    assert exchange["grant_type"] == "authorization_code" and exchange["client_id"] == "oaiapp_test"
    assert exchange["code"] == "the-code" and exchange["redirect_uri"] == query["redirect_uri"] and len(exchange["code_verifier"]) >= 43
    kept = json.loads(keyring(online)["chatgpt"])
    assert kept["client_id"] == "oaiapp_test" and kept["refresh_token"] == "refresh-1" and kept["email"] == "person@example.org"
    assert not files_hold(online, "access-1") and not files_hold(online, "refresh-1")
    assert online.client.ask("hello", pid=4242)["chatgpt"] == {"email": "person@example.org"}

    online.client.send(op="provider-models", provider="chatgpt", key=None)
    assert online.client.wait(lambda e: e["event"] == "provider-models")["models"] == [{"model": "gpt-test", "name": "GPT Test"}]
    online.client.ask("add-model", provider="chatgpt", model="gpt-test", name="GPT Test", key=None)

    online.client.send(op="grant", group="settings")
    online.provider.replies += [{"calls": [("set_volume", {"percent": 30})]}, {"text": ["Done."]}, {"text": ["Hi."]}]
    sent = online.client.ask("send", id=None, text="volume 30")
    online.client.card("done")
    online.client.done()
    (path, headers, first), (_, _, second) = online.provider.requests
    assert path == "/chatgpt/v1/responses" and headers["Authorization"] == "Bearer access-1"
    assert first["store"] is False and first["stream"] is True and "ShapeBit OS" in first["instructions"]
    assert first["input"] == [{"role": "user", "content": "volume 30"}]
    assert first["tools"][0]["type"] == "function" and "parameters" in first["tools"][0]
    assert second["input"][1:] == [
        {"type": "function_call", "call_id": "call_0", "name": "set_volume", "arguments": '{"percent": 30}'},
        {"type": "function_call_output", "call_id": "call_0", "output": "Volume is 30%."}]
    # A skill's temperature isn't sent: a ChatGPT plan takes none.
    online.provider.replies[:0] = [{"calls": [("use_skill", {"name": "writing"})]}, {"text": ["Dear team,"]}]
    online.client.send(op="send", id=sent["conversation"], text="write a letter")
    online.client.card("done")
    online.client.done()
    assert all("temperature" not in body for _, _, body in online.provider.requests)


def test_a_chatgpt_plans_limit_and_an_ended_sign_in_say_so(online):
    sign_in(online)
    online.client.ask("add-model", provider="chatgpt", model="gpt-test", name="GPT Test", key=None)
    online.provider.replies.append({"failed": "subscription_sharing_usage_limit_exceeded"})
    online.client.send(op="send", id=None, text="hello")
    assert "usage limit is reached" in online.client.done()["error"]
    online.provider.replies.append({"status": 429, "body": {"error": {"code": "subscription_sharing_usage_limit_exceeded", "message": "x"}}})
    online.client.send(op="send", id=None, text="hello")
    assert "chatgpt.com/settings/usage" in online.client.done()["error"]
    # The access token ends: it is refreshed with the issued client id, and the new refresh token kept.
    kept = json.loads(keyring(online)["chatgpt"])
    (online.tmp / "keyring" / "chatgpt").write_text(json.dumps({**kept, "expires_at": time.time() - 10}))
    online.provider.replies.append({"text": ["Hi."]})
    online.client.send(op="send", id=None, text="hello")
    assert online.client.done()["text"] == "Hi."
    refresh = online.provider.tokens[-1]
    assert refresh == {"grant_type": "refresh_token", "client_id": "oaiapp_test", "refresh_token": "refresh-1", "resource": "https://api.openai.com/v1"}
    assert json.loads(keyring(online)["chatgpt"])["refresh_token"] == "refresh-2"
    assert online.provider.requests[-1][1]["Authorization"] == "Bearer access-2"
    # The refresh token ended: signing in again is the way.
    kept = json.loads(keyring(online)["chatgpt"])
    (online.tmp / "keyring" / "chatgpt").write_text(json.dumps({**kept, "expires_at": 0, "refresh_token": "gone"}))
    online.client.send(op="send", id=None, text="hello")
    assert "sign in again" in online.client.done()["error"]


def test_signing_out_revokes_and_forgets_the_plans_models(online):
    sign_in(online)
    online.client.ask("add-model", provider="chatgpt", model="gpt-test", name="GPT Test", key=None)
    online.client.send(op="chatgpt-sign-out")
    online.client.wait(lambda e: e["event"] == "chatgpt" and e["signedIn"] is False)
    assert online.provider.revoked == [{"token": "refresh-1", "token_type_hint": "refresh_token", "client_id": "oaiapp_test"}]
    state = online.client.ask("hello", pid=4242)
    assert state["chatgpt"] is None and all(m.get("provider") != "chatgpt" for m in state["models"])
    # The client id stays for the next sign-in, which then sends it, not a new registration.
    assert json.loads(keyring(online)["chatgpt"]) == {"client_id": "oaiapp_test"}
    query = dict(urllib.parse.parse_qsl(urllib.parse.urlsplit(online.client.ask("chatgpt-sign-in")["url"]).query))
    assert query["client_id"] == "oaiapp_test" and "agent_name_hint" not in query


def test_a_model_needs_its_key_or_sign_in_to_be_added(online):
    assert online.client.ask("add-model", provider="anthropic", model="claude-test-1", name="", key=None)["error"] == "Enter the API key."
    assert online.client.ask("add-model", provider="chatgpt", model="gpt-test", name="", key=None)["error"] == "Continue with ChatGPT first."
    assert online.client.ask("add-model", provider="nobody", model="x", name="", key=None)["error"]


def test_each_api_gets_pictures_in_its_own_shape():
    picture = {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,SlBFRw=="}}
    messages = [{"role": "system", "content": "Be brief."},
                {"role": "user", "content": "look"},
                {"role": "assistant", "content": "", "tool_calls": [{"id": "c1", "type": "function", "function": {"name": "look_at_screen", "arguments": '{"workspace": 0}'}}]},
                {"role": "tool", "tool_call_id": "c1", "content": "A picture follows."},
                {"role": "user", "content": [{"type": "text", "text": "[The pictures]"}, picture]}]  # fmt: skip
    _, claude = models.build_anthropic({}, messages, [], {"temperature": 1.5})
    assert claude["system"] == "Be brief." and claude["temperature"] == 1.0
    assert [t["role"] for t in claude["messages"]] == ["user", "assistant", "user"]
    assert claude["messages"][2]["content"] == [
        {"type": "tool_result", "tool_use_id": "c1", "content": "A picture follows."},
        {"type": "text", "text": "[The pictures]"},
        {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": "SlBFRw=="}}]
    _, plan = models.build_responses({}, messages, [], {"temperature": 0.8})
    assert plan["instructions"] == "Be brief." and "temperature" not in plan
    assert plan["input"][-1] == {"role": "user", "content": [{"type": "input_text", "text": "[The pictures]"},
                                                             {"type": "input_image", "image_url": "data:image/jpeg;base64,SlBFRw=="}]}  # fmt: skip


def test_the_keyring_is_reached_on_the_bus_named_for_it_and_its_failure_says_why(tmp_path, monkeypatch):
    # make run's session bus has no keyring: secret-tool alone goes to the host's.
    import providers

    tool = tmp_path / "secret-tool"
    tool.write_text(f'#!/bin/bash\necho "$DBUS_SESSION_BUS_ADDRESS" > "{tmp_path}/bus"\n'
                    '[ "$1" = store ] && { echo "Cannot create an item in a locked collection" >&2; exit 1; }\nexit 1\n')  # fmt: skip
    tool.chmod(0o755)
    monkeypatch.setenv("PATH", f"{tmp_path}:{__import__('os').environ['PATH']}")
    monkeypatch.setenv("DBUS_SESSION_BUS_ADDRESS", "unix:path=/run/dev-bus")
    monkeypatch.setenv("ASSISTANT_KEYRING_BUS", "unix:path=/run/host-bus")
    with pytest.raises(providers.Failed, match="couldn't keep it: Cannot create an item in a locked collection"):
        providers.keep_key("anthropic", "sk-ant")
    assert (tmp_path / "bus").read_text().strip() == "unix:path=/run/host-bus"
    monkeypatch.delenv("ASSISTANT_KEYRING_BUS")
    assert providers.secret("anthropic") is None
    assert (tmp_path / "bus").read_text().strip() == "unix:path=/run/dev-bus"
