"""The SBOM, in SPDX, must add what syft cannot see, and fail
unless syft found exactly the installed RPMs, whose sources are published."""

import importlib.util
import pathlib
import re

import pytest

spec = importlib.util.spec_from_file_location("sbom", pathlib.Path(__file__).parents[1] / "sbom" / "sbom.py")
sbom = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sbom)

RELEASE = {"IMAGE_VERSION": "202611160900", "IMAGE_REVISION": "abc123"}
# `rpm -qa` lines of NAME, PROVIDENAME, PROVIDEVERSION, as sbom.py queries them.
PROVIDES = """python3-sherpa-onnx\tpython3-sherpa-onnx\t2.0.1-1.fc45
python3-sherpa-onnx\tbundled(utf8proc)\t2.12.0
python3-sherpa-onnx\tbundled(kissfft)\t0^20250528gitfebd4ca
bootc\tbundled(crate(serde))\t1.0.228
bootc\tbundled(crate(serde/default))\t1.0.228
glib2\tbundled(gnulib)\t
glib2\tglib2\t2.86.0-1.fc45
bootc\tbootc\t1.8.0-1.fc45
libstdc++\tlibstdc++\t16.2.1-3.fc45
gpg-pubkey\tgpg-pubkey\t1-1
"""
INSTALLED = ("python3-sherpa-onnx", "bootc", "glib2", "libstdc++")
# Extras as the image's catalog lists them (packages/extras/data/extras.json).
EXTRAS = [
    {"id": "parakeet", "name": "Dictation", "credits": [
        {"work": "Parakeet TDT 0.6B v3", "by": "NVIDIA", "license": "CC-BY-4.0", "url": "https://example.com/parakeet"},
        {"work": "Silero VAD", "by": "Silero", "license": "MIT", "url": "https://example.com/silero"}]},
    {"id": "gemma", "name": "Assistant", "credits": [
        {"work": "Gemma 4 E2B", "by": "Google", "license": "Apache-2.0", "url": "https://example.com/gemma",
         "changes": "quantized"}]},
]  # fmt: skip
ITEMS = sbom.additions(RELEASE, EXTRAS, sbom.bundled(PROVIDES))
WORKS = {c["work"] for e in EXTRAS for c in e["credits"]}
# What syft writes for a binary's package note: no source RPM, not an installed RPM.
NOTE = "pkg:rpm/fedora/audit@4.2.1-2.fc45?distro=fedora-45"


def purl(name):
    return f"pkg:rpm/shapebit/{name.replace('+', '%2B')}@1-1.fc45?arch=x86_64&upstream={name}-1-1.fc45.src.rpm"


def spdx_scan(rpms=INSTALLED):
    """A minimal syft SPDX document."""
    packages = [{"SPDXID": sbom.spdx_id("Package-rpm", name), "name": name, "externalRefs": [
        {"referenceCategory": "PACKAGE-MANAGER", "referenceType": "purl", "referenceLocator": url}]}
        for name, url in [(n, purl(n)) for n in rpms] + [("audit", NOTE)]]
    return {"packages": packages, "creationInfo": {"creators": ["Tool: syft"]}, "relationships": [
        {"spdxElementId": "SPDXRef-DOCUMENT", "relationshipType": "DESCRIBES", "relatedSpdxElement": "SPDXRef-Root"}]}


def spdx(rpms=INSTALLED):
    return sbom.to_spdx(spdx_scan(rpms), ITEMS, sbom.installed(PROVIDES), "The brand's terms.")


def related(doc, relation, target):
    ids = {p["SPDXID"]: p["name"] for p in doc["packages"]}
    return {ids[r["relatedSpdxElement"]] if r["spdxElementId"] == target else ids[r["spdxElementId"]]
            for r in doc["relationships"] if r["relationshipType"] == relation
            and target in (r["spdxElementId"], r["relatedSpdxElement"])}


def test_bundled_reads_only_bundled_provides():
    assert sbom.bundled(PROVIDES) == {
        "python3-sherpa-onnx": [("kissfft", "0^20250528gitfebd4ca"), ("utf8proc", "2.12.0")],
        "bootc": [("crate(serde)", "1.0.228")], "glib2": [("gnulib", "")]}


def test_installed_rpms_are_every_name_but_imported_keys():
    assert sbom.installed(PROVIDES) == set(INSTALLED)


def test_spdx_adds_shapebit_and_what_rpms_bundle():
    doc = spdx()
    by_name = {p["name"]: p for p in doc["packages"]}
    assert by_name["ShapeBit OS"]["versionInfo"] == "202611160900"
    assert by_name["ShapeBit OS"]["downloadLocation"].endswith("@abc123")
    assert by_name["ShapeBit OS"]["licenseDeclared"] == "GPL-3.0-or-later AND LGPL-3.0-or-later AND MIT AND LicenseRef-Brand"
    assert related(doc, "CONTAINS", "SPDXRef-Root") == {"ShapeBit OS"}
    assert related(doc, "CONTAINS", sbom.spdx_id("Package-rpm", "python3-sherpa-onnx")) == {"utf8proc", "kissfft"}
    assert related(doc, "CONTAINS", sbom.spdx_id("Package-rpm", "bootc")) == {"crate(serde)"}
    assert by_name["crate(serde)"]["externalRefs"][0]["referenceLocator"] == "pkg:cargo/serde@1.0.228"
    assert by_name["gnulib"]["versionInfo"] == "NOASSERTION"


def test_spdx_models_are_optional_components_with_their_licenses():
    doc = spdx()
    shapebit = next(p["SPDXID"] for p in doc["packages"] if p["name"] == "ShapeBit OS")
    assert related(doc, "OPTIONAL_COMPONENT_OF", shapebit) == WORKS
    assert all(p["licenseDeclared"] != "NOASSERTION" for p in doc["packages"] if p["name"] in WORKS)


def test_spdx_defines_the_brands_license_once_with_its_text():
    # syft may define it from the RPMs' License tags, with no real text.
    doc = spdx_scan()
    doc["hasExtractedLicensingInfos"] = [{"licenseId": "LicenseRef-Brand", "extractedText": "Brand"},
                                         {"licenseId": "LicenseRef-Other", "extractedText": "other"}]
    infos = sbom.to_spdx(doc, ITEMS, sbom.installed(PROVIDES), "The brand's terms.")["hasExtractedLicensingInfos"]
    assert [(i["licenseId"], i["extractedText"]) for i in infos] == [
        ("LicenseRef-Other", "other"), ("LicenseRef-Brand", "The brand's terms.")]


def test_spdx_identifiers_are_unique_and_valid():
    ids = [p["SPDXID"] for p in spdx()["packages"]]
    assert len(ids) == len(set(ids))
    assert all(re.fullmatch(r"SPDXRef-[A-Za-z0-9.-]+", i) for i in ids)


@pytest.mark.parametrize("rpms", [(), INSTALLED[1:], (*INSTALLED, "kernel")])
def test_a_scan_that_differs_from_the_installed_rpms_fails(rpms):
    with pytest.raises(ValueError, match="syft"):
        spdx(rpms)


def test_os_release_is_parsed():
    assert sbom.os_release('NAME="ShapeBit"\n# note\nIMAGE_VERSION=dev\n') == {"NAME": "ShapeBit", "IMAGE_VERSION": "dev"}
