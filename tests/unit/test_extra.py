"""desktop/extras/extra, against a made-up server on this machine: only a whole,
correct extra ever appears, and a broken download goes on from where it stopped."""

import hashlib
import http.server
import io
import json
import os
import re
import pathlib
import subprocess
import tarfile
import threading

import pytest

ROOT = pathlib.Path(__file__).parents[2]
EXTRA = ROOT / "desktop" / "extras" / "extra"


def tar_of(files):
    data = io.BytesIO()
    with tarfile.open(fileobj=data, mode="w:bz2") as tar:
        for name, content in files.items():
            info = tarfile.TarInfo(name)
            info.size = len(content)
            tar.addfile(info, io.BytesIO(content))
    return data.getvalue()


class Server:
    def __init__(self):
        self.files = {}
        self.ranges = []
        self.cut_after = None
        self.ignore_ranges = False
        outer = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_GET(self):
                data = outer.files.get(self.path)
                if data is None:
                    self.send_error(404)
                    return
                wanted = self.headers.get("Range")
                outer.ranges.append(wanted)
                start = 0
                if wanted and not outer.ignore_ranges:
                    start = int(wanted.removeprefix("bytes=").removesuffix("-"))
                    self.send_response(206)
                else:
                    self.send_response(200)
                body = data[start:]
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                if outer.cut_after is not None:
                    self.wfile.write(body[: outer.cut_after])
                    self.wfile.flush()
                    self.connection.close()
                    outer.cut_after = None
                    return
                self.wfile.write(body)

        self.http = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=self.http.serve_forever, daemon=True).start()

    def url(self, path):
        return f"http://127.0.0.1:{self.http.server_port}{path}"


class Extras:
    def __init__(self, tmp_path):
        self.server = Server()
        self.place = tmp_path / "extras"
        self.place.mkdir()
        self.catalog = tmp_path / "extras.json"
        self.archive = tar_of({"model/weights.onnx": b"weights" * 1000, "model/tokens.txt": b"tokens", "model/other.txt": b"not wanted"})
        self.plain = b"detector" * 100
        self.server.files = {"/model.tar.bz2": self.archive, "/detector.onnx": self.plain}
        self.write_catalog()

    def write_catalog(self, archive_hash=None, unpacked=1000):
        self.catalog.write_text(json.dumps([{
            "id": "model", "name": "A model", "detail": "For tests", "unpacked": unpacked,
            "credits": [{"work": "A model", "by": "someone", "license": "a license", "changes": "made smaller", "url": "https://example.com/model"}],
            "downloads": [
                {"url": self.server.url("/model.tar.bz2"), "bytes": len(self.archive), "files": ["model/weights.onnx", "model/tokens.txt"],
                 "sha256": archive_hash or hashlib.sha256(self.archive).hexdigest()},
                {"url": self.server.url("/detector.onnx"), "bytes": len(self.plain), "sha256": hashlib.sha256(self.plain).hexdigest()},
            ],
        }]))  # fmt: skip

    def run(self, *args, **env):
        env = {**os.environ, "EXTRAS_DIR": str(self.place), "EXTRAS_CATALOG": str(self.catalog), **env}
        done = subprocess.run([EXTRA, *args], capture_output=True, text=True, env=env, timeout=30)
        return done.returncode, [json.loads(line) for line in done.stdout.splitlines()]

    def listed(self):
        return self.run("list")[1][0]

    @property
    def visible(self):
        return sorted(path.name for path in self.place.iterdir() if not path.name.startswith("."))


@pytest.fixture
def extras(tmp_path):
    return Extras(tmp_path)


def test_install_makes_the_named_files_appear_and_nothing_else(extras):
    code, said = extras.run("install", "model")
    assert code == 0
    assert said[-1] == {"done": "model"}
    files = sorted(path.name for path in (extras.place / "model").iterdir())
    assert files == ["NOTICE", "detector.onnx", "tokens.txt", "weights.onnx"]
    assert (extras.place / "model" / "tokens.txt").read_bytes() == b"tokens"
    notice = (extras.place / "model" / "NOTICE").read_text()
    assert notice == "A model by someone, under a license, made smaller: https://example.com/model\n"


def test_install_leaves_no_working_files(extras):
    extras.run("install", "model")
    assert [path.name for path in extras.place.iterdir() if path.name != ".lock"] == ["model"]


def test_everyone_can_read_what_was_installed(extras):
    extras.run("install", "model")
    assert (extras.place / "model").stat().st_mode & 0o777 == 0o755
    assert (extras.place / "model" / "weights.onnx").stat().st_mode & 0o777 == 0o644


def test_progress_is_told_and_ends_at_the_whole(extras):
    _, said = extras.run("install", "model")
    percents = [line["percent"] for line in said if "percent" in line]
    assert percents == sorted(percents)
    assert percents[-1] == 100


def test_list_tells_size_and_state(extras):
    before = extras.listed()
    assert before["writable"] is True
    assert before["extras"][0]["installed"] is False
    assert before["extras"][0]["bytes"] == len(extras.archive) + len(extras.plain)
    assert before["extras"][0]["credits"][0]["license"] == "a license"
    extras.run("install", "model")
    assert extras.listed()["extras"][0]["installed"] is True


def test_a_wrong_hash_installs_nothing_and_the_next_try_starts_over(extras):
    extras.write_catalog(archive_hash="0" * 64)
    code, said = extras.run("install", "model")
    assert code == 1
    assert "damaged" in said[-1]["error"]
    assert extras.visible == []
    extras.write_catalog()
    extras.server.ranges.clear()
    assert extras.run("install", "model")[0] == 0
    assert extras.server.ranges[0] is None


def test_a_broken_connection_installs_nothing_and_the_next_try_goes_on(extras):
    extras.server.cut_after = 100
    code, said = extras.run("install", "model")
    assert code == 1
    assert "error" in said[-1]
    assert extras.visible == []
    extras.server.ranges.clear()
    assert extras.run("install", "model")[0] == 0
    assert extras.server.ranges[0] == "bytes=100-"
    assert (extras.place / "model" / "weights.onnx").read_bytes() == b"weights" * 1000


def test_a_server_that_ignores_the_range_still_gives_the_right_file(extras):
    extras.server.cut_after = 100
    extras.run("install", "model")
    extras.server.ignore_ranges = True
    assert extras.run("install", "model")[0] == 0
    assert (extras.place / "model" / "tokens.txt").read_bytes() == b"tokens"


def test_no_connection_says_so(extras):
    extras.server.http.shutdown()
    extras.server.http.server_close()
    code, said = extras.run("install", "model")
    assert code == 1
    assert "connect" in said[-1]["error"]


def test_an_archive_without_its_files_installs_nothing(extras):
    extras.archive = tar_of({"model/weights.onnx": b"weights"})
    extras.server.files["/model.tar.bz2"] = extras.archive
    extras.write_catalog()
    code, said = extras.run("install", "model")
    assert code == 1
    assert "missing" in said[-1]["error"]
    assert extras.visible == []


def test_an_archive_cannot_write_elsewhere(extras, tmp_path):
    extras.archive = tar_of({"model/weights.onnx": b"w", "model/tokens.txt": b"t", "../../escaped": b"bad"})
    extras.server.files["/model.tar.bz2"] = extras.archive
    extras.write_catalog()
    assert extras.run("install", "model")[0] == 0
    assert not (tmp_path / "escaped").exists()
    assert not (extras.place / "escaped").exists()


def test_too_little_room_downloads_nothing(extras):
    extras.write_catalog(unpacked=2**62)
    extras.server.ranges.clear()
    code, said = extras.run("install", "model")
    assert code == 1
    assert "disk space" in said[-1]["error"]
    assert extras.server.ranges == []


def test_installing_what_is_installed_downloads_nothing(extras):
    extras.run("install", "model")
    extras.server.ranges.clear()
    assert extras.run("install", "model") == (0, [{"done": "model"}])
    assert extras.server.ranges == []


def test_remove_takes_it_away_and_what_was_half_downloaded(extras):
    extras.run("install", "model")
    assert extras.run("remove", "model")[0] == 0
    assert extras.visible == []
    assert extras.listed()["extras"][0]["installed"] is False
    extras.server.cut_after = 100
    extras.run("install", "model")
    assert extras.run("remove", "model")[0] == 0
    assert [path.name for path in extras.place.iterdir() if path.name != ".lock"] == []


def test_a_person_who_may_not_write_is_told(extras):
    extras.place.chmod(0o555)
    try:
        if os.access(extras.place, os.W_OK):
            pytest.skip("running as root")
        assert extras.listed()["writable"] is False
        code, said = extras.run("install", "model")
        assert code == 1
        assert "administrator" in said[-1]["error"]
    finally:
        extras.place.chmod(0o755)


def test_unknown_extra_is_refused(extras):
    code, said = extras.run("install", "../../etc")
    assert code == 1
    assert "no extra" in said[-1]["error"]
    assert extras.visible == []


def test_shipped_catalog_is_complete():
    entries = json.loads((ROOT / "desktop" / "extras" / "extras.json").read_text())
    assert entries
    for extra in entries:
        assert {"id", "name", "detail", "unpacked", "credits", "downloads"} <= set(extra)
        for credit in extra["credits"]:
            assert {"work", "by", "license", "url"} <= set(credit)
            assert credit["url"].startswith("https://")
        for item in extra["downloads"]:
            assert item["url"].startswith("https://")
            assert len(item["sha256"]) == 64
            assert item["bytes"] > 0


def test_every_download_is_pinned_to_a_revision():
    # A download's hash holds only while its URL serves the same bytes: a
    # release asset under a tag can be replaced, as sherpa-onnx's Parakeet was
    # on 2026-11-07, and every install then failed as damaged. A Hugging Face
    # commit cannot change.
    entries = json.loads((ROOT / "desktop" / "extras" / "extras.json").read_text())
    for extra in entries:
        for item in extra["downloads"]:
            assert re.fullmatch(r"https://huggingface\.co/[\w.-]+/[\w.-]+/resolve/[0-9a-f]{40}/\S+", item["url"]), item["url"]


def test_live_dictation_finds_what_its_extra_installs():
    entries = json.loads((ROOT / "desktop" / "extras" / "extras.json").read_text())
    parakeet = next(extra for extra in entries if extra["id"] == "parakeet")
    names = {pathlib.PurePosixPath(name).name for item in parakeet["downloads"] for name in item.get("files", [])}
    names |= {pathlib.PurePosixPath(item["url"]).name for item in parakeet["downloads"] if "files" not in item}
    engine = (ROOT / "desktop" / "dictation" / "dictate-engine").read_text()
    names |= {item["as"] for item in parakeet["downloads"] if "as" in item}
    for name in ("encoder.int8.onnx", "decoder.int8.onnx", "joiner.int8.onnx", "tokens.txt", "silero_vad_v5.onnx", "smart-turn.onnx"):
        assert name in names
        assert name in engine
    assert '"/var/lib/extras/parakeet"' in (ROOT / "desktop" / "dictation" / "hear").read_text()


def test_a_piper_voice_is_prepared_for_sherpa_onnx(extras):
    # Piper's own files: the model, and its config with the phonemes' numbers.
    config = {"language": {"name_english": "Polish"}, "espeak": {"voice": "pl"}, "num_speakers": 1,
              "audio": {"sample_rate": 22050}, "vowel_clusters": [["a", "ɪ"], ["o", "ʊ"]],
              "phoneme_id_map": {"_": [0], "a": [14], "ɪ": [74], "aɪ": [161], "oʊ": [165], "xy": [200]}}  # fmt: skip
    model = b"\x08\x07onnx-model"
    raw = json.dumps(config).encode()
    extras.server.files = {"/pl.onnx": model, "/pl.onnx.json": raw}
    extras.catalog.write_text(json.dumps([{
        "id": "voices", "name": "Voices", "detail": "For tests", "unpacked": 1000, "prepare": "piper",
        "credits": [{"work": "A voice", "by": "someone", "license": "CC0", "url": "https://example.com/voice"}],
        "downloads": [{"url": extras.server.url(path), "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
                      for path, data in extras.server.files.items()],
    }]))  # fmt: skip
    assert extras.run("install", "voices")[0] == 0
    place = extras.place / "voices"
    # One character each: a vowel cluster as a private one, in the config's order;
    # other symbols of more than one character are left out.
    assert (place / "pl.tokens").read_text() == "_ 0\na 14\nɪ 74\n\ue000 161\n\ue001 165\n"
    # The model, untouched, then sherpa-onnx's metadata as ONNX's metadata_props.
    prepared = (place / "pl.onnx").read_bytes()
    assert prepared.startswith(model)
    entries, at = {}, len(model)
    while at < len(prepared):
        assert prepared[at] == 0x72
        size = prepared[at + 1]
        entry = prepared[at + 2 : at + 2 + size]
        key = entry[2 : 2 + entry[1]]
        value = entry[2 + entry[1] + 2 :]
        entries[key.decode()] = value.decode()
        at += 2 + size
    assert entries == {"model_type": "vits", "comment": "piper", "language": "Polish", "voice": "pl", "has_espeak": "1",
                       "n_speakers": "1", "sample_rate": "22050"}  # fmt: skip


def test_piper_voices_are_not_offered_or_shipped():
    entries = json.loads((ROOT / "desktop" / "extras" / "extras.json").read_text())
    assert all(extra["id"] != "voices" and extra.get("prepare") != "piper" for extra in entries)
    assert "piper-voices" not in json.dumps(entries)
    settings = (ROOT / "desktop" / "shell" / "settings" / "SettingsWindow.qml").read_text()
    assert "Settings.assistantSpeaks" not in settings


def test_a_download_can_be_named(extras):
    catalog = json.loads(extras.catalog.read_text())
    catalog[0]["downloads"][1]["as"] = "model.gguf"
    extras.catalog.write_text(json.dumps(catalog))
    assert extras.run("install", "model")[0] == 0
    assert (extras.place / "model" / "model.gguf").read_bytes() == extras.plain
    assert not (extras.place / "model" / "detector.onnx").exists()


def test_list_tells_whether_the_computer_has_memory_enough(extras, tmp_path):
    catalog = json.loads(extras.catalog.read_text())
    catalog[0]["memory"] = 7_000_000_000
    extras.catalog.write_text(json.dumps(catalog))
    meminfo = tmp_path / "meminfo"
    meminfo.write_text("MemTotal:        7810000 kB\n")
    assert extras.run("list", EXTRAS_MEMINFO=str(meminfo))[1][0]["extras"][0]["fits"] is True
    meminfo.write_text("MemTotal:        3900000 kB\n")
    assert extras.run("list", EXTRAS_MEMINFO=str(meminfo))[1][0]["extras"][0]["fits"] is False


def test_every_extra_fits_in_the_room_the_installer_leaves():
    # The installer's reserve keeps steadyRoom beside the first owner's home
    # (installer/backend/disks.h); all the extras must install there together.
    header = (ROOT / "installer" / "backend" / "disks.h").read_text()
    factors = re.search(r"steadyRoom = ([\d* LL]+);", header).group(1).replace("LL", "").split("*")
    room = 1
    for factor in factors:
        room *= int(factor)
    entries = json.loads((ROOT / "desktop" / "extras" / "extras.json").read_text())
    needed = sum(extra["unpacked"] + sum(item["bytes"] for item in extra["downloads"]) for extra in entries)
    assert needed <= room
