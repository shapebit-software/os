"""Sign in with ChatGPT: the person's ChatGPT plan answers for the assistant,
as OpenAI documents it for open-source and local apps
(https://developers.openai.com/siwc/token-sharing-open-source), written from
those docs. No API key and no client secret: the first sign-in registers
this installation, and OpenAI gives it a client id.

The person signs in in their own browser, on OpenAI's page; the answer comes
back to a listener on 127.0.0.1 (OAuth authorization code with PKCE). The
tokens, with the client id, are in the keyring (providers.py), never in a
file or a log: the access token lasts an hour, and the refresh token, which
changes with each refresh, 30 days. Signing out clears local tokens and attempts
remote revocation, reporting when it could not be confirmed.
"""

import base64
import hashlib
import html
import http.server
import json
import os
import pathlib
import secrets
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

import providers

AUTH = os.environ.get("ASSISTANT_CHATGPT_AUTH", "https://auth.openai.com")
RESOURCE = "https://api.openai.com/v1"
SCOPE = "openid profile email offline_access resource.invoke chatgpt.tokens.use.direct"
NEEDED = "chatgpt.tokens.use.direct"
APP = "ShapeBit OS"
# How long a sign-in waits for the person, in seconds.
WAIT = 600
# Refresh this long, in seconds, before the access token ends.
EARLY = 120
LOCK = threading.Lock()


class Failed(Exception):
    """The message is for people."""


def host_id():
    """This installation's id, kept from the first sign-in."""
    path = pathlib.Path(os.environ.get("XDG_CONFIG_HOME") or pathlib.Path.home() / ".config") / "assistant" / "host-id"
    try:
        return path.read_text().strip()
    except OSError:
        made = f"urn:uuid:{uuid.uuid4()}"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(made + "\n")
        return made


def record():
    found = providers.secret("chatgpt")
    try:
        return json.loads(found) if found else None
    except ValueError:
        return None


def save(kept):
    providers.keep("chatgpt", "Assistant: ChatGPT sign-in", json.dumps(kept))


def account():
    """{"email"} of the account signed in, or None."""
    kept = record()
    return {"email": kept.get("email", "")} if kept and kept.get("refresh_token") else None


def post(path, fields):
    request = urllib.request.Request(AUTH + path, urllib.parse.urlencode(fields).encode(),
                                     {"Content-Type": "application/x-www-form-urlencoded", "Accept": "application/json"})  # fmt: skip
    try:
        with urllib.request.urlopen(request, timeout=30) as reply:
            body = reply.read()
            return json.loads(body) if body.strip() else {}
    except urllib.error.HTTPError as error:
        try:
            return {"error": json.loads(error.read()).get("error", f"http_{error.code}")}
        except ValueError:
            return {"error": f"http_{error.code}"}
    except (urllib.error.URLError, OSError, ValueError):
        raise Failed("Couldn't reach OpenAI.") from None


def configuration():
    """Discover keys and revocation from the same issuer used for sign-in."""
    try:
        with urllib.request.urlopen(AUTH + "/.well-known/openid-configuration", timeout=10) as reply:
            found = json.load(reply)
        if found["issuer"] != AUTH:
            raise ValueError("wrong issuer")
        return found
    except (OSError, ValueError, KeyError):
        raise Failed("Couldn't verify OpenAI's sign-in configuration.") from None


def identity(token, client_id, nonce):
    """Validate identity with issuer keys, not an unverified JWT payload."""
    # Only an enabled sign-in needs PyJWT and its cryptography backend.
    import jwt

    try:
        keys = jwt.PyJWKClient(configuration()["jwks_uri"], timeout=10)
        key = keys.get_signing_key_from_jwt(token).key
        found = jwt.decode(token, key, algorithms=["RS256", "ES256"], audience=client_id, issuer=AUTH,
                           options={"require": ["iss", "aud", "exp", "sub", "nonce"]})  # fmt: skip
        if not isinstance(found["nonce"], str) or not secrets.compare_digest(found["nonce"], nonce):
            raise ValueError("wrong nonce")
        if not isinstance(found["sub"], str) or not found["sub"]:
            raise ValueError("missing subject")
        return found
    except (jwt.PyJWTError, OSError, ValueError, KeyError):
        raise Failed("OpenAI's sign-in identity couldn't be verified. Try signing in again.") from None


class SignIn:
    """One sign-in: url is the page to open; done(error or None) is called
    when it ends."""

    def __init__(self, done):
        self.done = done
        self.state = secrets.token_urlsafe(24)
        self.verifier = secrets.token_urlsafe(48)
        self.nonce = secrets.token_urlsafe(24)
        kept = record() or {}
        self.client_id = kept.get("client_id")
        self.subject = kept.get("subject")
        outer = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_GET(self):
                parts = urllib.parse.urlsplit(self.path)
                if parts.path != "/auth/callback":
                    self.send_error(404)
                    return
                error = outer.callback(dict(urllib.parse.parse_qsl(parts.query)))
                page = ("Signed in. You can close this page and go back to ShapeBit." if not error
                        else f"Not signed in: {html.escape(error)} You can close this page.")  # fmt: skip
                body = f"<!doctype html><meta charset=utf-8><title>ShapeBit</title><p style='font:16px sans-serif'>{page}</p>".encode()
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                threading.Thread(target=outer.server.shutdown, daemon=True).start()

        # Only the port may change between sign-ins: the host and path stay.
        self.server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
        self.redirect = f"http://127.0.0.1:{self.server.server_address[1]}/auth/callback"
        challenge = base64.urlsafe_b64encode(hashlib.sha256(self.verifier.encode()).digest()).rstrip(b"=").decode()
        query = {"client_id": self.client_id or "dynamic_agent_client", "ext_agent_host_id": host_id(), "response_type": "code",
                 "redirect_uri": self.redirect, "scope": SCOPE, "resource": RESOURCE, "state": self.state,
                 "nonce": self.nonce, "code_challenge_method": "S256", "code_challenge": challenge}  # fmt: skip
        if not self.client_id:
            query["agent_name_hint"] = APP
        elif kept.get("id_token"):
            query["id_token_hint"] = kept["id_token"]
        self.url = f"{AUTH}/api/accounts/authorize?" + urllib.parse.urlencode(query)
        self.ended = False
        threading.Thread(target=self.serve, daemon=True).start()

    def serve(self):
        timer = threading.Timer(WAIT, self.server.shutdown)
        timer.daemon = True
        timer.start()
        self.server.serve_forever()
        self.server.server_close()
        timer.cancel()
        if not self.ended:
            self.end("The sign-in took too long, or was cancelled.")

    def cancel(self):
        threading.Thread(target=self.server.shutdown, daemon=True).start()

    def end(self, error):
        self.ended = True
        self.done(error)

    def callback(self, query):
        """The browser's return: the error for people, or None."""
        if query.get("state") != self.state:
            return "The answer didn't belong to this sign-in."
        if self.ended:
            return None
        if query.get("error"):
            error = "You declined." if query["error"] == "access_denied" else f"OpenAI answered {query['error']}."
            self.end(error)
            return error
        issued = query.get("client_id") or self.client_id
        if not issued or self.client_id and issued != self.client_id:
            self.end("OpenAI gave no client id.")
            return "OpenAI gave no client id."
        try:
            tokens = post("/api/accounts/oauth/token", {
                "grant_type": "authorization_code", "client_id": issued, "code": query.get("code", ""),
                "code_verifier": self.verifier, "redirect_uri": self.redirect, "resource": RESOURCE})  # fmt: skip
            if "access_token" not in tokens:
                raise Failed(f"OpenAI didn't sign you in ({tokens.get('error', 'no token')}).")
            user = identity(tokens.get("id_token", ""), issued, self.nonce)
            if self.subject and user["sub"] != self.subject:
                raise Failed("This installation is registered to a different OpenAI account. Sign in with the original account.")
            if NEEDED not in (tokens.get("scope") or "").split():
                raise Failed("Using your ChatGPT plan here wasn't allowed. Your plan may not include it.")
            with LOCK:
                save({"client_id": issued, "subject": user["sub"], "email": user.get("email", ""), "id_token": tokens["id_token"],
                      "access_token": tokens["access_token"], "refresh_token": tokens.get("refresh_token", ""),
                      "expires_at": time.time() + float(tokens.get("expires_in", 3600)), "scope": tokens.get("scope", "")})  # fmt: skip
        except (Failed, providers.Failed) as error:
            self.end(str(error))
            return str(error)
        self.end(None)
        return None


def access_token():
    """A valid access token, refreshed if it is about to end; Failed if the
    person must sign in again."""
    with LOCK:
        kept = record()
        if not kept or not kept.get("refresh_token"):
            raise Failed("Sign in to ChatGPT in Settings > Assistant > Models.")
        if kept.get("expires_at", 0) - EARLY > time.time():
            return kept["access_token"]
        tokens = post("/api/accounts/oauth/token", {"grant_type": "refresh_token", "client_id": kept["client_id"],
                                                    "refresh_token": kept["refresh_token"], "resource": RESOURCE})  # fmt: skip
        if "access_token" not in tokens:
            if tokens.get("error") == "invalid_client":
                raise Failed("OpenAI no longer knows this installation; sign in to ChatGPT again.")
            # The refresh token is used up, ended, or taken back: only signing in again helps.
            save({"client_id": kept["client_id"], "email": kept.get("email", ""),
                  **({"subject": kept["subject"]} if kept.get("subject") else {})})
            raise Failed("The ChatGPT sign-in ended; sign in again in Settings > Assistant > Models.")
        kept.update(access_token=tokens["access_token"], refresh_token=tokens.get("refresh_token") or kept["refresh_token"],
                    expires_at=time.time() + float(tokens.get("expires_in", 3600)))  # fmt: skip
        save(kept)
        return kept["access_token"]


def sign_out():
    """Revokes the sign-in at OpenAI, then forgets it here; the client id
    stays, for the next sign-in."""
    with LOCK:
        kept = record()
        if not kept:
            return
        warning = None
        if kept.get("refresh_token"):
            for attempt in range(2):
                try:
                    endpoint = configuration()["revocation_endpoint"]
                    # Reject an unexpected origin before sending a refresh token.
                    if not endpoint.startswith(AUTH + "/"):
                        raise Failed("Unexpected revocation endpoint.")
                    result = post(endpoint[len(AUTH):], {"token": kept["refresh_token"], "token_type_hint": "refresh_token",
                                                       "client_id": kept["client_id"]})  # fmt: skip
                    if result.get("error"):
                        raise Failed("Revocation was refused.")
                    break
                except (Failed, KeyError):
                    if attempt == 0:
                        time.sleep(0.2)
                    else:
                        warning = "Signed out on this computer. Remote revocation wasn't confirmed; disconnect ShapeBit in ChatGPT Settings."
        save({"client_id": kept["client_id"], **({"subject": kept["subject"]} if kept.get("subject") else {})})
        return warning
