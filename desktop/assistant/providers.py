"""The online providers a person adds models from, in Settings > Assistant >
Models: how each is reached, how its models are listed, and where its
credentials are kept. models.py streams answers through them.

No online providers are registered in the shipped system. ChatGPT sign-in and
generic API-key storage, discovery and protocols remain for future integrations.

Keys and ChatGPT's tokens are in the keyring (secret-tool), never in a file:
attribute assistant-provider, the provider's id. In development, make run's
session bus has no keyring, so ASSISTANT_KEYRING_BUS names the host's, which
secret-tool alone uses.
"""

import http.client
import json
import os
import subprocess
import urllib.parse


def url_of(provider, default):
    """The API's base; tests point it at a made-up server."""
    return os.environ.get(f"ASSISTANT_{provider.upper()}_URL", default)


# id: name, how the person signs in ("plan" or "key"), the API it speaks, its
# base, the mark and color its models show with, and where its usage is managed.
# Retained for a future integration; registering it requires an explicit code change.
CHATGPT = {"name": "ChatGPT", "auth": "plan", "api": "responses", "url": url_of("chatgpt", "https://api.openai.com/v1"),
           "mark": "C", "color": "#10a37f", "usage": "https://chatgpt.com/settings/usage"}  # fmt: skip
PROVIDERS = {}
ANTHROPIC_VERSION = "2023-06-01"
# Of a provider's models, those that are not for chat.
NOT_CHAT = ("embed", "tts", "whisper", "audio", "realtime", "transcribe", "image", "dall-e", "moderation", "search",
            "imagen", "veo", "live", "aqa", "babbage", "davinci", "computer-use", "codex")  # fmt: skip


class Failed(Exception):
    """The message is for people."""


# The keyring.


def keyring_env():
    bus = os.environ.get("ASSISTANT_KEYRING_BUS")
    return {**os.environ, "DBUS_SESSION_BUS_ADDRESS": bus} if bus else None


def secret(provider):
    try:
        found = subprocess.run(["secret-tool", "lookup", "assistant-provider", provider], capture_output=True, text=True,
                               timeout=10, env=keyring_env())  # fmt: skip
    except (OSError, subprocess.TimeoutExpired):
        return None
    return found.stdout.strip() if found.returncode == 0 and found.stdout.strip() else None


def keep(provider, label, value):
    try:
        done = subprocess.run(["secret-tool", "store", f"--label={label}", "assistant-provider", provider],
                              input=value, capture_output=True, text=True, timeout=10, env=keyring_env())  # fmt: skip
    except (OSError, subprocess.TimeoutExpired) as error:
        raise Failed(f"The keyring couldn't keep it: {error}.") from None
    if done.returncode != 0:
        reason = (done.stderr or "").strip().splitlines()[-1:] or ["no keyring answered"]
        raise Failed(f"The keyring couldn't keep it: {reason[0]}.")


def forget(provider):
    try:
        subprocess.run(["secret-tool", "clear", "assistant-provider", provider], capture_output=True, timeout=10, env=keyring_env())
    except (OSError, subprocess.TimeoutExpired):
        pass


def keep_key(provider, key):
    keep(provider, f"Assistant: {PROVIDERS[provider]['name']} API key", key.strip())


# Asking a provider.


def headers(provider, credential):
    if PROVIDERS[provider]["api"] == "anthropic":
        return {"x-api-key": credential, "anthropic-version": ANTHROPIC_VERSION}
    return {"Authorization": f"Bearer {credential}"}


def get(url, extra):
    parts = urllib.parse.urlsplit(url)
    kind = http.client.HTTPSConnection if parts.scheme == "https" else http.client.HTTPConnection
    connection = kind(parts.netloc, timeout=30)
    try:
        connection.request("GET", parts.path + (f"?{parts.query}" if parts.query else ""), headers={"Accept": "application/json", **extra})
        reply = connection.getresponse()
        body = reply.read(4_000_000)
    except OSError as error:
        raise Failed(f"Couldn't reach the provider: {error}.") from None
    finally:
        connection.close()
    if reply.status in (401, 403):
        raise Failed("The provider refused the key, or the sign-in.")
    if reply.status != 200:
        raise Failed(f"The provider answered {reply.status}.")
    try:
        return json.loads(body)
    except ValueError:
        raise Failed("The provider's answer couldn't be read.") from None


def list_models(provider, credential):
    """[{"model", "name"}]: the chat models the credential may use, as the
    provider lists them."""
    found = get(PROVIDERS[provider]["url"] + "/models", headers(provider, credential))
    if provider == "chatgpt":
        # Sign in with ChatGPT lists {"models": [{slug, display_name, visibility}]}, in the order to keep.
        return [{"model": m["slug"], "name": m.get("display_name") or m["slug"]}
                for m in found.get("models", []) if m.get("visibility") == "list"]  # fmt: skip
    models = []
    for m in found.get("data", []):
        model = str(m.get("id", "")).removeprefix("models/")
        if not model or any(word in model for word in NOT_CHAT):
            continue
        models.append({"model": model, "name": m.get("display_name") or model})
    if PROVIDERS[provider]["api"] != "anthropic":
        # Newest, by name, first: the providers list in no useful order.
        models.sort(key=lambda m: m["model"], reverse=True)
    return models


def entry(provider, model, name):
    """A model's catalog entry (models.py)."""
    p = PROVIDERS[provider]
    return {"id": f"{provider}:{model}", "name": name or model, "mark": p["mark"], "color": p["color"], "where": "online",
            "provider": provider, "api": p["api"], "url": p["url"], "model": model, "vision": True}  # fmt: skip
