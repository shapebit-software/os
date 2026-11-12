"""The web, for the assistant's actions (actions.py): a page's main text, and
Wikipedia's articles, with Python alone, so it is always there. No page's
JavaScript runs: a page that needs it says so, and the person's browser can
open it.

Only public addresses are reached: a page, or a redirect, to this computer
or the local network fails, so that no text the model read can make it ask
the router or a service on this computer for something.
"""

import html.parser
import ipaddress
import json
import os
import re
import socket
import urllib.error
import urllib.parse
import urllib.request

# The most text of a page the model gets, in characters: its context holds
# 8192 tokens, with the conversation.
MOST_TEXT = 6000
MOST_BYTES = 3_000_000
TIMEOUT = 15
# Who asks, as Wikipedia's policy wants it told: the OS, not the person.
AGENT = "ShapeBitOS-Assistant/1.0 (https://shapebit.software)"
# In tests: this computer's loopback address may be reached, never the local
# network, and Wikipedia is elsewhere.
LOCAL = os.environ.get("ASSISTANT_WEB_LOCAL") == "1"
WIKIPEDIA = os.environ.get("ASSISTANT_WIKIPEDIA", "https://{language}.wikipedia.org")


class Failed(Exception):
    """The message is for people and the model."""


def public(host):
    """Whether every address the host has is on the internet."""
    try:
        found = {info[4][0] for info in socket.getaddrinfo(host, None)}
    except (socket.gaierror, UnicodeError):
        raise Failed(f"{host} wasn't found.") from None
    addresses = [ipaddress.ip_address(address.split("%")[0]) for address in found]
    return all(a.is_global or LOCAL and a.is_loopback for a in addresses)


def checked(url):
    """The URL, if it is one the assistant may reach."""
    parts = urllib.parse.urlsplit(url.strip())
    if parts.scheme not in ("http", "https") or not parts.hostname:
        raise Failed("Only web addresses, http or https, can be read.")
    if not public(parts.hostname):
        raise Failed(f"{parts.hostname} is on this computer or the local network, which the assistant doesn't reach.")
    return parts.geturl()


class Redirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, url):
        return super().redirect_request(request, fp, code, message, headers, checked(url))


def fetch(url, accept="text/html,text/plain;q=0.9"):
    """(final URL, content type, text) of a page."""
    opener = urllib.request.build_opener(Redirects)
    request = urllib.request.Request(checked(url), headers={"User-Agent": AGENT, "Accept": accept})
    try:
        with opener.open(request, timeout=TIMEOUT) as reply:
            kind = reply.headers.get_content_type()
            if not kind.startswith("text/") and kind not in ("application/xhtml+xml", "application/json"):
                raise Failed(f"That address is a file ({kind}), not a page to read.")
            data = reply.read(MOST_BYTES)
            charset = reply.headers.get_content_charset()
            final = reply.geturl()
    except urllib.error.HTTPError as error:
        raise Failed(f"The site answered {error.code} {error.reason}.") from None
    except (urllib.error.URLError, OSError) as error:
        reason = getattr(error, "reason", error)
        raise Failed(reason.args[0] if isinstance(reason, Failed) else f"The site couldn't be reached: {reason}.") from None
    if not charset:
        found = re.search(rb"""<meta[^>]+charset=["']?([\w-]+)""", data[:4096], re.I)
        charset = found.group(1).decode() if found else "utf-8"
    try:
        return final, kind, data.decode(charset, errors="replace")
    except LookupError:
        return final, kind, data.decode("utf-8", errors="replace")


class Text(html.parser.HTMLParser):
    """A page's title and readable text: headings, paragraphs, and lists,
    without scripts, menus, and forms; the main or article part's alone, if
    the page marks one. A list that is nearly all links, such as a menu or the
    page's other languages, is left out."""

    SKIPPED = {"script", "style", "noscript", "template", "svg", "nav", "header", "footer", "aside", "form", "button", "select"}
    VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"}
    BLOCKS = {"p", "div", "section", "tr", "table", "ul", "ol", "dl", "blockquote", "pre", "figure", "dd", "dt"}
    MAIN = {"main", "article"}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.title = ""
        self.in_title = False
        self.skipping = []
        self.main_depth = 0
        self.all = []
        self.main = []
        self.scripts = 0
        # The lists open: [where their text starts in all and main, their
        # characters, those in links]; and how deep in links this is.
        self.lists = []
        self.in_link = 0

    def handle_starttag(self, tag, attrs):
        if tag == "script":
            self.scripts += 1
        if tag in self.VOID:
            if tag == "br" and not self.skipping:
                self.add("\n")
            return
        attributes = dict(attrs)
        if self.skipping or tag in self.SKIPPED and not (tag == "header" and self.main_depth) \
                or "hidden" in attributes or attributes.get("aria-hidden") == "true":  # fmt: skip
            self.skipping.append(tag)
            return
        if tag == "title":
            self.in_title = True
        if tag == "a":
            self.in_link += 1
        if tag in ("ul", "ol"):
            self.lists.append([len(self.all), len(self.main), 0, 0])
        if tag in self.MAIN:
            self.main_depth += 1
        if re.fullmatch(r"h[1-6]", tag):
            self.add("\n\n" + "#" * int(tag[1]) + " ")
        elif tag == "li":
            self.add("\n- ")
        elif tag in self.BLOCKS:
            self.add("\n")

    def handle_endtag(self, tag):
        if self.skipping:
            # Pages leave tags open, such as p: what was opened since closes too.
            if tag in self.skipping:
                del self.skipping[len(self.skipping) - 1 - self.skipping[::-1].index(tag):]
            return
        if tag == "title":
            self.in_title = False
        if tag == "a" and self.in_link:
            self.in_link -= 1
        if tag in ("ul", "ol") and self.lists:
            all_at, main_at, chars, linked = self.lists.pop()
            if chars and linked / chars > 0.8:
                del self.all[all_at:], self.main[main_at:]
                return
        if tag in self.MAIN and self.main_depth:
            self.main_depth -= 1
        if re.fullmatch(r"h[1-6]", tag) or tag in self.BLOCKS:
            self.add("\n")

    def handle_data(self, data):
        if self.in_title:
            self.title += data
        elif not self.skipping:
            for held in self.lists:
                held[2] += len(data.strip())
                held[3] += len(data.strip()) if self.in_link else 0
            self.add(data)

    def add(self, text):
        self.all.append(text)
        if self.main_depth:
            self.main.append(text)

    def text(self):
        def tidy(pieces):
            lines = [" ".join(line.split()) for line in "".join(pieces).split("\n")]
            return re.sub(r"\n{3,}", "\n\n", "\n".join(lines)).strip()

        main = tidy(self.main)
        return main if len(main) >= 200 else tidy(self.all)


def cut(text, most=MOST_TEXT):
    if len(text) <= most:
        return text
    end = text.rfind("\n", 0, most)
    return text[: end if end > most // 2 else most].rstrip() + "\n\n(The page goes on; only its start is here.)"


def read_page(url):
    """What the model reads of a page: its title, address, and main text."""
    final, kind, body = fetch(url)
    if kind == "text/plain":
        return f"{final}\n\n{cut(body.strip())}"
    parser = Text()
    parser.feed(body)
    parser.close()
    text = parser.text()
    if len(text) < 200 and parser.scripts:
        raise Failed("This page shows its content with JavaScript, which the assistant doesn't run. "
                     "The person's browser can open it (open_url).")  # fmt: skip
    title = " ".join(parser.title.split())
    return f"{title}\n{final}\n\n{cut(text)}" if title else f"{final}\n\n{cut(text)}"


def language():
    """The person's language, for Wikipedia's edition, such as "pl"."""
    code = os.environ.get("LANG", "en").split("_")[0].split(".")[0].lower()
    return code if re.fullmatch(r"[a-z]{2,3}", code) and code != "c" else "en"


def search_wikipedia(query, most=3):
    """The articles that match best, each with its title, address, and start;
    in the person's language, or else in English."""
    for code in dict.fromkeys([language(), "en"]):
        base = WIKIPEDIA.format(language=code)
        url = f"{base}/w/api.php?" + urllib.parse.urlencode({
            "action": "query", "format": "json", "formatversion": "2", "generator": "search", "gsrsearch": query,
            "gsrlimit": most, "prop": "extracts|info", "inprop": "url", "exintro": "1", "explaintext": "1", "exlimit": most})  # fmt: skip
        try:
            pages = json.loads(fetch(url, "application/json")[2]).get("query", {}).get("pages", [])
        except ValueError:
            raise Failed("Wikipedia's answer couldn't be read.") from None
        if pages:
            pages.sort(key=lambda p: p.get("index", 0))
            return "\n\n".join(f"# {p['title']}\n{p.get('fullurl', '')}\n{cut(p.get('extract', '').strip(), MOST_TEXT // most)}"
                               for p in pages)  # fmt: skip
    return f"Wikipedia has no article that matches {query}."
