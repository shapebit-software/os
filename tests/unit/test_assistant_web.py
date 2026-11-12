"""desktop/assistant/web.py: a page's main text, without menus, lists of links, and scripts,
cut to what the model holds; pages that need JavaScript or are files say so;
only public addresses are reached, redirects too; and Wikipedia is searched
in the person's language, then in English."""

import http.server
import json
import pathlib
import sys
import threading
import urllib.parse

import pytest

sys.path.insert(0, str(pathlib.Path(__file__).parents[2] / "desktop" / "assistant"))
import web  # noqa: E402

ARTICLE = """<!doctype html><html><head><meta charset="utf-8"><title> The  Otter </title>
<script>track()</script><style>p { color: red }</style></head><body>
<nav><a href="/">Home</a> <a href="/news">News</a></nav>
<div hidden><p>Hidden offer</div>
<main><article><header><h1>Otters</h1></header>
<ul class="languages"><li><a href="/de">Deutsch</a><li><a href="/pl">Polski</a></ul>
<p>Otters are <b>semi-aquatic</b> mammals.<br>They eat fish.</p>
<ul><li>Sea otter<li>River otter</ul>
<p>""" + "They hold hands while sleeping. " * 8 + """</p></article></main>
<aside>Ad: buy now</aside><footer>© Zoo</footer></body></html>"""


@pytest.fixture
def site(monkeypatch):
    """A made-up site on this computer: {path: (status, type, body, headers)}."""
    monkeypatch.setattr(web, "LOCAL", True)
    pages = {}
    asked = []

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def do_GET(self):
            asked.append((self.path, self.headers.get("User-Agent")))
            status, kind, body, headers = pages.get(urllib.parse.urlsplit(self.path).path, (404, "text/plain", "gone", {}))
            data = body.encode() if isinstance(body, str) else body
            self.send_response(status)
            self.send_header("Content-Type", kind)
            self.send_header("Content-Length", str(len(data)))
            for name, value in headers.items():
                self.send_header(name, value)
            self.end_headers()
            self.wfile.write(data)

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    site = type("Site", (), {"pages": pages, "asked": asked, "url": f"http://127.0.0.1:{server.server_address[1]}"})
    yield site
    server.shutdown()
    server.server_close()


def test_a_page_is_its_title_address_and_main_text(site):
    site.pages["/otters"] = (200, "text/html", ARTICLE, {})
    said = web.read_page(site.url + "/otters")
    assert said.startswith(f"The Otter\n{site.url}/otters\n\n# Otters\n\nOtters are semi-aquatic mammals.\nThey eat fish.")
    assert "- Sea otter\n- River otter" in said
    for left_out in ("Home", "track()", "color", "Hidden offer", "Deutsch", "Ad:", "Zoo"):
        assert left_out not in said
    assert site.asked[0][1].startswith("ShapeBitOS-Assistant/")


def test_a_long_page_is_cut_and_says_so(site):
    site.pages["/long"] = (200, "text/plain; charset=utf-8", "line of text\n" * 2000, {})
    said = web.read_page(site.url + "/long")
    assert len(said) < web.MOST_TEXT + 200 and said.endswith("(The page goes on; only its start is here.)")


def test_a_page_that_needs_javascript_or_is_a_file_says_so(site):
    site.pages["/app"] = (200, "text/html", "<html><body><div id=root></div><script src=app.js></script></body></html>", {})
    site.pages["/report.pdf"] = (200, "application/pdf", b"%PDF-1.7", {})
    site.pages["/gone"] = (404, "text/html", "<p>no</p>", {})
    for path, why in (("/app", "JavaScript"), ("/report.pdf", r"a file \(application/pdf\)"), ("/gone", "answered 404")):
        with pytest.raises(web.Failed, match=why):
            web.read_page(site.url + path)


def test_only_public_addresses_are_reached_redirects_too(site, monkeypatch):
    site.pages["/away"] = (302, "text/html", "", {"Location": "http://10.0.0.1/admin"})
    with pytest.raises(web.Failed, match="10.0.0.1 is on this computer or the local network"):
        web.read_page(site.url + "/away")
    monkeypatch.setattr(web, "LOCAL", False)
    for url in ("http://127.0.0.1/", "http://192.168.1.1/", "http://[::1]/", "http://169.254.169.254/latest"):
        with pytest.raises(web.Failed, match="local network"):
            web.checked(url)
    with pytest.raises(web.Failed, match="Only web addresses"):
        web.checked("file:///etc/passwd")
    assert web.checked("https://8.8.8.8/x") == "https://8.8.8.8/x"


def test_wikipedia_is_searched_in_the_persons_language_then_in_english(site, monkeypatch):
    monkeypatch.setattr(web, "WIKIPEDIA", site.url + "/{language}")
    monkeypatch.setenv("LANG", "pl_PL.UTF-8")
    site.pages["/pl/w/api.php"] = (200, "application/json", json.dumps({"batchcomplete": True}), {})
    site.pages["/en/w/api.php"] = (200, "application/json", json.dumps({"query": {"pages": [
        {"title": "River otter", "index": 2, "fullurl": "https://en.wikipedia.org/wiki/River_otter", "extract": "Lives in rivers."},
        {"title": "Otter", "index": 1, "fullurl": "https://en.wikipedia.org/wiki/Otter", "extract": "A mammal."}]}}), {})  # fmt: skip
    said = web.search_wikipedia("otter")
    assert said == ("# Otter\nhttps://en.wikipedia.org/wiki/Otter\nA mammal.\n\n"
                    "# River otter\nhttps://en.wikipedia.org/wiki/River_otter\nLives in rivers.")
    assert [urllib.parse.parse_qs(urllib.parse.urlsplit(p).query)["gsrsearch"] for p, _ in site.asked] == [["otter"], ["otter"]]
    assert [urllib.parse.urlsplit(p).path for p, _ in site.asked] == ["/pl/w/api.php", "/en/w/api.php"]
    site.pages["/en/w/api.php"] = (200, "application/json", json.dumps({}), {})
    assert web.search_wikipedia("zzzz") == "Wikipedia has no article that matches zzzz."
