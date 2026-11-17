"""The SBOM must add what syft cannot see, and fail unless syft found exactly the
installed RPMs, whose sources are published."""

import importlib.util
import json
import pathlib
import re

import pytest

ROOT = pathlib.Path(__file__).parents[2]
spec = importlib.util.spec_from_file_location("sbom", ROOT / "scripts/sbom.py")
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
BUNDLED = sbom.bundled(PROVIDES)
EXTRAS = json.loads((ROOT / "desktop/extras/extras.json").read_text())


def rpm(name, purl=None):
    """syft's entry of an installed RPM; PURL for another kind of entry."""
    purl = purl or f"pkg:rpm/shapebit/{name.replace('+', '%2B')}@1-1.fc45?arch=x86_64&upstream={name}-1-1.fc45.src.rpm"
    return {"SPDXID": sbom.spdx_id("Package-rpm", name), "name": name, "externalRefs": [
        {"referenceCategory": "PACKAGE-MANAGER", "referenceType": "purl", "referenceLocator": purl}]}


def scan(rpms=("python3-sherpa-onnx", "bootc", "glib2", "libstdc++")):
    """A minimal syft document, with an entry from a binary's package note as syft writes it."""
    packages = [rpm(name) for name in rpms] + [rpm("audit", "pkg:rpm/fedora/audit@4.2.1-2.fc45?distro=fedora-45")]
    return {"packages": packages, "creationInfo": {"creators": ["Tool: syft"]}, "relationships": [
        {"spdxElementId": "SPDXRef-DOCUMENT", "relationshipType": "DESCRIBES", "relatedSpdxElement": "SPDXRef-Root"}]}


def complete(doc):
    return sbom.complete(doc, RELEASE, "PolyForm Shield", EXTRAS, sbom.installed(PROVIDES), BUNDLED)


def related(doc, relation, target):
    ids = {p["SPDXID"]: p["name"] for p in doc["packages"]}
    return {ids[r["relatedSpdxElement"]] if r["spdxElementId"] == target else ids[r["spdxElementId"]]
            for r in doc["relationships"] if r["relationshipType"] == relation
            and target in (r["spdxElementId"], r["relatedSpdxElement"])}


def test_adds_shapebit_and_what_rpms_bundle():
    doc = complete(scan())
    by_name = {p["name"]: p for p in doc["packages"]}
    assert by_name["ShapeBit OS"]["versionInfo"] == "202611160900"
    assert by_name["ShapeBit OS"]["downloadLocation"].endswith("@abc123")
    assert by_name["ShapeBit OS"]["licenseDeclared"] in {i["licenseId"] for i in doc["hasExtractedLicensingInfos"]}
    assert related(doc, "CONTAINS", "SPDXRef-Root") == {"ShapeBit OS"}
    assert related(doc, "CONTAINS", "SPDXRef-Package-rpm-python3-sherpa-onnx") == {"utf8proc", "kissfft"}
    assert related(doc, "CONTAINS", "SPDXRef-Package-rpm-bootc") == {"crate(serde)"}
    serde = next(p for p in doc["packages"] if p["name"] == "crate(serde)")
    assert serde["externalRefs"][0]["referenceLocator"] == "pkg:cargo/serde@1.0.228"
    assert next(p for p in doc["packages"] if p["name"] == "gnulib")["versionInfo"] == "NOASSERTION"


def test_bundled_reads_only_bundled_provides():
    assert BUNDLED == {"python3-sherpa-onnx": [("kissfft", "0^20250528gitfebd4ca"), ("utf8proc", "2.12.0")],
                       "bootc": [("crate(serde)", "1.0.228")], "glib2": [("gnulib", "")]}


def test_models_are_optional_components_with_their_licenses():
    doc = complete(scan())
    shapebit = next(p["SPDXID"] for p in doc["packages"] if p["name"] == "ShapeBit OS")
    works = {c["work"] for e in EXTRAS for c in e["credits"]}
    assert related(doc, "OPTIONAL_COMPONENT_OF", shapebit) == works
    assert all(p["licenseDeclared"] != "NOASSERTION" for p in doc["packages"] if p["name"] in works)


def test_identifiers_are_unique_and_valid():
    ids = [p["SPDXID"] for p in complete(scan())["packages"]]
    assert len(ids) == len(set(ids))
    assert all(set(i.removeprefix("SPDXRef-")) <= set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.-")
               for i in ids)


def test_installed_rpms_are_every_name_but_imported_keys():
    assert sbom.installed(PROVIDES) == {"python3-sherpa-onnx", "bootc", "glib2", "libstdc++"}


@pytest.mark.parametrize("rpms", [(), ("bootc", "glib2", "libstdc++"), ("python3-sherpa-onnx", "bootc", "glib2", "libstdc++", "kernel")])
def test_a_scan_that_differs_from_the_installed_rpms_fails(rpms):
    with pytest.raises(ValueError, match="syft"):
        complete(scan(rpms))


def test_os_release_is_parsed():
    assert sbom.os_release('NAME="ShapeBit"\n# note\nIMAGE_VERSION=dev\n') == {"NAME": "ShapeBit", "IMAGE_VERSION": "dev"}


def test_each_credit_has_an_spdx_license_id():
    # A single ID: the notice links to its page on spdx.org.
    assert all(re.fullmatch(r"[A-Za-z0-9.+-]+", c["license"]) for e in EXTRAS for c in e["credits"])
