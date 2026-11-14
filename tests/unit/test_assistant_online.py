"""Online models (desktop/assistant/providers.py, chatgpt.py, models.py),
against made-up providers: a model is added with an API key, which stays in
the keyring, or by signing in with ChatGPT, whose tokens stay there too; each
API, Claude's and OpenAI's Responses, gets the conversation in its own shape
and streams back text and tool calls; a ChatGPT plan's limits and an ended
sign-in say so; and removing or signing out forgets what was kept."""

import http.server
import json
import pathlib
import sys
import threading
import time
import urllib.parse
import urllib.request

import pytest
import jwt
from cryptography.hazmat.primitives.asymmetric import rsa

sys.path.insert(0, str(pathlib.Path(__file__).parents[2] / "desktop" / "assistant"))
import models  # noqa: E402
import providers  # noqa: E402
from test_assistant import Setup  # noqa: E402


class Provider:
    """A made-up provider: Claude's and OpenAI's APIs, and OpenAI's sign-in.
    Each POST answer is from a script: {"text": [...]} or {"calls":
    [(name, arguments)]}, or {"status", "body"}."""

    def __init__(self):
        self.replies = []
        self.requests = []
        self.tokens = []
        self.revoked = []
        self.key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        self.nonce = ""
        self.token_claims = {}
        self.bad_signature = False
        self.revoke_status = 200
        self.scope = "openid profile email offline_access resource.invoke chatgpt.tokens.use.direct"
        self.models = {"test-key": {"data": [{"id": "test-model-1", "display_name": "Test model"}]},
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
                if self.path == "/auth/.well-known/openid-configuration":
                    return self.reply(200, {"issuer": outer.url + "/auth", "jwks_uri": outer.url + "/auth/jwks",
                                            "revocation_endpoint": outer.url + "/auth/api/accounts/oauth/revoke"})  # fmt: skip
                if self.path == "/auth/jwks":
                    key = jwt.algorithms.RSAAlgorithm.to_jwk(outer.key.public_key(), as_dict=True)
                    return self.reply(200, {"keys": [{**key, "kid": "test", "alg": "RS256", "use": "sig"}]})
                if self.path == "/test-key/v1/models":
                    if self.headers.get("x-api-key") != "test-key-secret":
                        return self.reply(401, {"error": {"message": "invalid x-api-key"}})
                    return self.reply(200, outer.models["test-key"])
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
                        return self.reply(outer.revoke_status, b"" if outer.revoke_status == 200 else {"error": "unavailable"})
                    outer.tokens.append(fields)
                    if fields["grant_type"] == "refresh_token" and fields["refresh_token"] == "gone":
                        return self.reply(400, {"error": "refresh_token_expired"})
                    outer.refresh_counter += 1
                    claims = {"iss": outer.url + "/auth", "aud": fields["client_id"], "sub": "test-person", "exp": time.time() + 3600,
                              "nonce": outer.nonce, "email": "person@example.org", **outer.token_claims}  # fmt: skip
                    token = jwt.encode(claims, outer.key, algorithm="RS256", headers={"kid": "test"})
                    if outer.bad_signature:
                        token = token.rsplit(".", 1)[0] + ".invalid-signature"
                    return self.reply(200, {"access_token": f"access-{outer.refresh_counter}", "refresh_token": f"refresh-{outer.refresh_counter}",
                                            "id_token": token, "token_type": "Bearer", "expires_in": 3600,
                                            "scope": outer.scope})  # fmt: skip
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
def online(tmp_path, monkeypatch):
    provider = Provider()
    made = Setup(tmp_path)
    made.env.update(ASSISTANT_CHATGPT_URL=f"{provider.url}/chatgpt/v1",
                    ASSISTANT_CHATGPT_AUTH=f"{provider.url}/auth")  # fmt: skip
    made.stop()
    # Enable the retained implementation only in these test processes.
    monkeypatch.setitem(providers.PROVIDERS, "chatgpt", providers.CHATGPT)
    source = pathlib.Path(__file__).parents[2] / "desktop" / "assistant"
    bootstrap = (f"import sys, runpy; sys.path.insert(0, {str(source)!r}); "
                 "import providers; providers.PROVIDERS['chatgpt'] = providers.CHATGPT; "
                 f"sys.argv = [{str(source / 'assistant')!r}, 'serve']; "
                 f"runpy.run_path({str(source / 'assistant')!r}, run_name='__main__')")
    made.command = [sys.executable, "-c", bootstrap]
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


def test_disabled_service_starts_without_chatgpt_libraries(tmp_path):
    source = pathlib.Path(__file__).parents[2] / "desktop" / "assistant"
    bootstrap = ("import sys, runpy; sys.modules['jwt'] = None; sys.modules['cryptography'] = None; "
                 f"sys.path.insert(0, {str(source)!r}); "
                 f"sys.argv = [{str(source / 'assistant')!r}, 'serve']; "
                 f"runpy.run_path({str(source / 'assistant')!r}, run_name='__main__')")
    made = Setup(tmp_path, command=[sys.executable, "-c", bootstrap])
    try:
        assert made.state["providers"] == {} and made.state["chatgpt"] is None
        assert made.client.ask("chatgpt-sign-in")["error"] == "This provider is not supported."
    finally:
        made.stop()
        made.model.close()


@pytest.mark.parametrize("provider", ["chatgpt", "gemini", "openai", "anthropic"])
def test_shipped_service_disables_online_providers(tmp_path, provider):
    made = Setup(tmp_path)
    try:
        assert made.state["providers"] == {} and made.state["chatgpt"] is None
        assert made.client.ask("add-model", provider=provider, model="retired-model", key="unused")["error"]
        assert made.client.ask("provider-models", provider=provider)["error"] == "This provider is not supported."
        assert made.client.ask("chatgpt-sign-in")["error"] == "This provider is not supported."
        assert made.client.ask("chatgpt-sign-out")["error"] == "This provider is not supported."
        assert keyring(made) == {}
        assert made.model.requests == []
    finally:
        made.stop()
        made.model.close()


@pytest.mark.parametrize("saved_model", [False, True])
def test_disabled_chatgpt_removes_saved_models_and_local_tokens(tmp_path, saved_model):
    made = Setup(tmp_path)
    try:
        made.stop()
        config = tmp_path / "config" / "assistant"
        config.mkdir(parents=True, exist_ok=True)
        entry = {"id": "chatgpt:old", "provider": "chatgpt", "where": "online", "model": "old"}
        (config / "models.json").write_text(json.dumps([entry] if saved_model else []))
        (config / "settings.json").write_text(json.dumps({"model": entry["id"] if saved_model else ""}))
        folder = tmp_path / "keyring"
        folder.mkdir(exist_ok=True)
        (folder / "chatgpt").write_text("old-token")
        made.start()
        assert made.state["chatgpt"] is None and made.state["providers"] == {}
        assert json.loads((config / "models.json").read_text()) == []
        assert made.settings()["model"] == ""
        assert keyring(made) == {}
        assert made.commands().count("secret-tool clear assistant-provider chatgpt") == 2  # Once per start.
        assert not any("secret-tool lookup assistant-provider chatgpt" in c for c in made.commands())
    finally:
        made.stop()
        made.model.close()


@pytest.mark.parametrize("retired_provider", ["gemini", "openai", "anthropic"])
def test_explicit_test_registration_enables_only_chatgpt(online, retired_provider):
    assert set(online.client.ask("hello", pid=4242)["providers"]) == {"chatgpt"}
    assert online.client.ask("add-model", provider=retired_provider, model="retired-model", key="removed-key")["error"]
    assert online.client.ask("provider-models", provider=retired_provider, key="removed-key")["error"] == "This provider is not supported."
    assert keyring(online) == {}
    assert online.provider.requests == [] and online.model.requests == []


@pytest.mark.parametrize("retired_provider", ["gemini", "openai", "anthropic"])
def test_retired_provider_cleanup_preserves_chatgpt_and_conversations(online, retired_provider):
    sign_in(online)
    online.client.ask("add-model", provider="chatgpt", model="gpt-test", key=None)
    sent = online.client.ask("send", id=None, text="Keep this conversation")
    online.client.done()
    credentials = keyring(online)
    online.stop()
    config = online.tmp / "config" / "assistant"
    path = config / "models.json"
    kept = json.loads(path.read_text())
    retired = {"id": f"{retired_provider}:retired-model", "provider": retired_provider, "where": "online",
               "url": online.provider.url + "/removed/v1", "model": "retired-model"}
    path.write_text(json.dumps([*kept, retired]))
    settings = online.settings()
    settings["model"] = retired["id"]
    (config / "settings.json").write_text(json.dumps(settings))
    (online.tmp / "keyring" / retired_provider).write_text("removed-key")

    online.start()
    assert json.loads(path.read_text()) == kept
    assert keyring(online) == credentials
    assert online.settings()["model"] == ""
    assert all(m.get("provider") != retired_provider for m in online.state["models"])
    assert online.state["model"]["id"] != retired["id"]
    assert online.state["chatgpt"]["email"] == "person@example.org"
    conversation = online.client.ask("open", id=sent["conversation"])
    assert conversation["messages"][0]["text"] == "Keep this conversation"


def test_api_key_machinery_still_stores_discovers_and_streams_with_a_test_provider(online, monkeypatch):
    # Register only in this test process; the shipped service exposes no providers.
    monkeypatch.setitem(providers.PROVIDERS, "test-key", {
        "name": "Test API", "auth": "key", "api": "anthropic", "url": online.provider.url + "/test-key/v1",
        "mark": "T", "color": "#123456", "usage": "https://example.org/usage",
    })
    for name in ("PATH", "XDG_RUNTIME_DIR"):
        monkeypatch.setenv(name, online.env[name])
    with pytest.raises(providers.Failed, match="refused the key"):
        providers.list_models("test-key", "wrong-key")
    providers.keep_key("test-key", " test-key-secret ")
    assert providers.secret("test-key") == "test-key-secret"
    assert not files_hold(online, "test-key-secret")
    assert providers.list_models("test-key", providers.secret("test-key")) == [
        {"model": "test-model-1", "name": "Test model"}]
    entry = providers.entry("test-key", "test-model-1", "Test model")
    online.provider.replies.append({"text": ["Still ", "working."], "calls": [("get_status", {})]})
    text = []
    answer, calls = models.Chat(entry).run([
        {"role": "system", "content": "Be brief."}, {"role": "user", "content": "Status?"}], [], text.append)
    assert answer == "Still working." and "".join(text) == answer
    assert calls == [{"id": "toolu_1", "name": "get_status", "arguments": "{}"}]
    path, headers, body = online.provider.requests[0]
    assert path == "/test-key/v1/messages"
    assert headers["x-api-key"] == "test-key-secret" and headers["anthropic-version"]
    assert body["model"] == "test-model-1" and body["system"] == "Be brief."
    providers.forget("test-key")
    assert keyring(online) == {}


def sign_in(made):
    """Continue with ChatGPT, with the test as the browser."""
    url = made.client.ask("chatgpt-sign-in")["url"]
    query = dict(urllib.parse.parse_qsl(urllib.parse.urlsplit(url).query))
    made.provider.nonce = query["nonce"]
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
    assert json.loads(keyring(online)["chatgpt"]) == {"client_id": "oaiapp_test", "subject": "test-person"}
    query = dict(urllib.parse.parse_qsl(urllib.parse.urlsplit(online.client.ask("chatgpt-sign-in")["url"]).query))
    assert query["client_id"] == "oaiapp_test" and "agent_name_hint" not in query


def test_a_model_needs_its_key_or_sign_in_to_be_added(online):
    assert online.client.ask("add-model", provider="chatgpt", model="gpt-test", name="", key=None)["error"] == "Continue with ChatGPT first."
    assert online.client.ask("add-model", provider="nobody", model="x", name="", key=None)["error"]


@pytest.mark.parametrize("claims,bad_signature", [
    ({"iss": "https://another-issuer.example"}, False),
    ({"aud": "another-client"}, False),
    ({"exp": 1}, False),
    ({"nonce": "another-attempt"}, False),
    ({"sub": ""}, False),
    ({}, True),
])
def test_chatgpt_rejects_unverified_identity_before_storing_tokens(online, claims, bad_signature):
    url = online.client.ask("chatgpt-sign-in")["url"]
    query = dict(urllib.parse.parse_qsl(urllib.parse.urlsplit(url).query))
    online.provider.nonce = query["nonce"]
    online.provider.token_claims = claims
    online.provider.bad_signature = bad_signature
    redirect = query["redirect_uri"] + "?" + urllib.parse.urlencode({"code": "the-code", "state": query["state"], "client_id": "oaiapp_test"})
    assert "couldn&#x27;t be verified" in urllib.request.urlopen(redirect, timeout=10).read().decode()
    event = online.client.wait(lambda e: e["event"] == "chatgpt" and "signedIn" in e)
    assert event["signedIn"] is False
    assert keyring(online) == {}


def test_callback_scopes_cannot_grant_permission_the_token_endpoint_did_not_grant(online):
    url = online.client.ask("chatgpt-sign-in")["url"]
    query = dict(urllib.parse.parse_qsl(urllib.parse.urlsplit(url).query))
    online.provider.nonce = query["nonce"]
    online.provider.scope = "openid email"
    redirect = query["redirect_uri"] + "?" + urllib.parse.urlencode(
        {"code": "the-code", "state": query["state"], "client_id": "oaiapp_test", "scope": query["scope"]})
    assert "wasn&#x27;t allowed" in urllib.request.urlopen(redirect, timeout=10).read().decode()
    assert online.client.wait(lambda e: e["event"] == "chatgpt" and "signedIn" in e)["signedIn"] is False
    assert keyring(online) == {}


def test_signing_out_reports_unconfirmed_revocation_and_clears_local_tokens(online):
    sign_in(online)
    online.provider.revoke_status = 503
    online.client.send(op="chatgpt-sign-out")
    event = online.client.wait(lambda e: e["event"] == "chatgpt" and e.get("signedIn") is False)
    assert "Remote revocation wasn't confirmed" in event["error"]
    assert len(online.provider.revoked) == 2
    assert "refresh_token" not in json.loads(keyring(online)["chatgpt"])


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
    monkeypatch.setitem(providers.PROVIDERS, "test-key", {"name": "Test API"})

    tool = tmp_path / "secret-tool"
    tool.write_text(f'#!/bin/bash\necho "$DBUS_SESSION_BUS_ADDRESS" > "{tmp_path}/bus"\n'
                    '[ "$1" = store ] && { echo "Cannot create an item in a locked collection" >&2; exit 1; }\nexit 1\n')  # fmt: skip
    tool.chmod(0o755)
    monkeypatch.setenv("PATH", f"{tmp_path}:{__import__('os').environ['PATH']}")
    monkeypatch.setenv("DBUS_SESSION_BUS_ADDRESS", "unix:path=/run/dev-bus")
    monkeypatch.setenv("ASSISTANT_KEYRING_BUS", "unix:path=/run/host-bus")
    with pytest.raises(providers.Failed, match="couldn't keep it: Cannot create an item in a locked collection"):
        providers.keep_key("test-key", "test-key-secret")
    assert (tmp_path / "bus").read_text().strip() == "unix:path=/run/host-bus"
    monkeypatch.delenv("ASSISTANT_KEYRING_BUS")
    assert providers.secret("test-key") is None
    assert (tmp_path / "bus").read_text().strip() == "unix:path=/run/dev-bus"
