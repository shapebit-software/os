"""ShapeBit's packages (third-party/): each Source is pinned by its hash, so a build
gets exactly what was reviewed, and the development container runs the version
the image builds."""

import pathlib
import re

import pytest

ROOT = pathlib.Path(__file__).parents[2]
PACKAGES = sorted(p for p in (ROOT / "third-party").iterdir() if p.is_dir())


def spec_sources(spec):
    """The file name of each Source of a spec: after `#/`, or the URL's last part."""
    text = spec.read_text()
    macros = dict(re.findall(r"^%global\s+(\S+)\s+(\S+)", text, re.M))
    macros |= {"url": re.search(r"^URL:\s*(\S+)", text, re.M | re.I)[1]}
    macros |= {"version": re.search(r"^Version:\s*(\S+)", text, re.M)[1]}

    def expand(value):
        while (expanded := re.sub(r"%\{(\w+)\}", lambda m: macros[m[1]], value)) != value:
            value = expanded
        return value

    names = []
    for url in re.findall(r"^Source\d*:\s*(\S+)", text, re.M):
        url = expand(url)
        names.append(url.split("#/", 1)[1] if "#/" in url else url.rsplit("/", 1)[1])
    return names


@pytest.mark.parametrize("package", PACKAGES, ids=lambda p: p.name)
def test_every_source_is_pinned_by_its_hash(package):
    sources = (package / "sources").read_text().splitlines()
    pinned = {line.split()[1]: line.split()[0] for line in sources}
    assert all(re.fullmatch(r"[0-9a-f]{64}", h) for h in pinned.values())
    assert sorted(pinned) == sorted(spec_sources(package / f"{package.name}.spec"))


def test_development_container_runs_the_version_the_image_builds():
    # scripts/dev-assistant.sh installs sherpa-onnx==<the spec's `%global ver`>.
    spec = (ROOT / "third-party/sherpa-onnx/sherpa-onnx.spec").read_text()
    assert re.search(r"^Version:\s*%\{ver\}$", spec, re.M)
    assert re.search(r"^%global ver \d+\.\d+\.\d+$", spec, re.M)
    script = (ROOT / "scripts/dev-assistant.sh").read_text()
    assert "sed -n 's/^%global ver //p' third-party/sherpa-onnx/sherpa-onnx.spec" in script
