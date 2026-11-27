"""External packages: software that ShapeBit builds and publishes in its own
repository (packages/repositories/README.md), each in the feature folder that needs it, as a folder
with its spec and a sources file. Each Source is pinned by its hash, so a build
gets exactly what was reviewed; and the feature requires the package it holds."""

import pathlib
import re

import pytest

ROOT = pathlib.Path(__file__).parents[3]
# A folder of external/ with a sources file is an external package; ShapeBit's own have none.
PACKAGES = sorted(path.parent for path in (ROOT / "packages").glob("*/external/*/sources"))
FEATURES = sorted(path.parent for path in (ROOT / "packages").glob("*/*.spec"))


def test_external_packages_are_found_where_they_should_be():
    assert {p.name for p in PACKAGES} == {"llama-server", "sherpa-onnx"}


def test_a_spec_below_a_feature_is_an_external_package_with_its_sources():
    # A spec deeper than a feature's top is external, so it needs pinned sources.
    for spec in (ROOT / "packages").glob("*/*/**/*.spec"):
        assert (spec.parent / "sources").exists(), spec


def built(package):
    """The binary packages that an external package's spec builds."""
    text = (package / f"{package.name}.spec").read_text()
    names = [package.name] if re.search(r"^%files\s*$", text, re.M) else []
    return names + [m.replace("%{name}", package.name) for m in re.findall(r"^%package\s+-n\s+(\S+)", text, re.M)]


@pytest.mark.parametrize("package", PACKAGES, ids=lambda p: p.name)
def test_the_feature_that_holds_an_external_package_requires_it(package):
    feature = package.parents[1]
    spec = (feature / f"{feature.name}.spec").read_text()
    required = set(re.findall(r"^Requires:\s*(\S+)", spec, re.M))
    assert required & set(built(package)), f"{feature.name}.spec requires none of {built(package)}"


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
    # Fedora's format, which `sha512sum -c` reads.
    lines = (package / "sources").read_text().splitlines()
    pinned = dict(re.fullmatch(r"SHA512 \((.+)\) = ([0-9a-f]{128})", line).groups() for line in lines)
    assert sorted(pinned) == sorted(spec_sources(package / f"{package.name}.spec"))


@pytest.mark.parametrize("package", PACKAGES, ids=lambda p: p.name)
def test_bundled_code_is_declared_by_a_package_that_is_built(package):
    # Tags before the first %package belong to the main package, which is built
    # only if it has its own %files; otherwise they reach no RPM.
    spec = (package / f"{package.name}.spec").read_text()
    main = spec.split("\n%package", 1)[0]
    if re.search(r"^%files\s*$", spec, re.M) is None:
        assert "bundled(" not in main
