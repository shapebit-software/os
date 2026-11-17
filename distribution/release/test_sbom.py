"""The SBOM, in SPDX and in CycloneDX, must add what syft cannot see, and fail
unless syft found exactly the installed RPMs, whose sources are published."""

import importlib.util
import json
import pathlib
import re

import pytest

ROOT = pathlib.Path(__file__).parents[2]
spec = importlib.util.spec_from_file_location("sbom", ROOT / "distribution/release/sbom.py")
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
EXTRAS = json.loads((ROOT / "packages/extras/extras.json").read_text())
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


def cyclonedx_scan(rpms=INSTALLED):
    """A minimal syft CycloneDX document."""
    components = [{"bom-ref": url, "type": "library", "name": name, "purl": url}
                  for name, url in [(n, purl(n)) for n in rpms] + [("audit", NOTE)]]
    return {"bomFormat": "CycloneDX", "specVersion": "1.6", "components": components,
            "metadata": {"tools": {"components": [{"type": "application", "name": "syft"}]}}}


def spdx(rpms=INSTALLED):
    return sbom.to_spdx(spdx_scan(rpms), ITEMS, sbom.installed(PROVIDES), "PolyForm Shield")


def cyclonedx(rpms=INSTALLED):
    return sbom.to_cyclonedx(cyclonedx_scan(rpms), ITEMS, sbom.installed(PROVIDES), "PolyForm Shield")


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
    assert by_name["ShapeBit OS"]["licenseDeclared"] in {i["licenseId"] for i in doc["hasExtractedLicensingInfos"]}
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


def test_spdx_identifiers_are_unique_and_valid():
    ids = [p["SPDXID"] for p in spdx()["packages"]]
    assert len(ids) == len(set(ids))
    assert all(re.fullmatch(r"SPDXRef-[A-Za-z0-9.-]+", i) for i in ids)


def test_cyclonedx_has_the_same_additions():
    doc = cyclonedx()
    top = {c["name"]: c for c in doc["components"]}
    nested = {c["name"]: c for parent in doc["components"] for c in parent.get("components", [])}
    assert top["ShapeBit OS"]["version"] == "202611160900"
    assert top["ShapeBit OS"]["licenses"][0]["license"]["text"]["content"] == "PolyForm Shield"
    assert {"utf8proc", "kissfft"} == {c["name"] for c in top["python3-sherpa-onnx"]["components"]}
    assert nested["crate(serde)"]["purl"] == "pkg:cargo/serde@1.0.228"
    assert "version" not in nested["gnulib"]
    models = {name: c for name, c in top.items() if name in WORKS}
    assert models.keys() == WORKS
    assert all(c["scope"] == "optional" and c["licenses"][0]["expression"] for c in models.values())
    assert "shapebit-sbom" in {t["name"] for t in doc["metadata"]["tools"]["components"]}


def test_cyclonedx_references_are_unique():
    doc = cyclonedx()
    refs = [c["bom-ref"] for parent in doc["components"] for c in [parent, *parent.get("components", [])]]
    assert len(refs) == len(set(refs))


def test_both_formats_list_the_same_additions():
    spdx_names = {p["name"] for p in spdx()["packages"]}
    doc = cyclonedx()
    cyclonedx_names = {c["name"] for parent in doc["components"] for c in [parent, *parent.get("components", [])]}
    assert spdx_names == cyclonedx_names


@pytest.mark.parametrize("make", [spdx, cyclonedx])
@pytest.mark.parametrize("rpms", [(), INSTALLED[1:], (*INSTALLED, "kernel")])
def test_a_scan_that_differs_from_the_installed_rpms_fails(make, rpms):
    with pytest.raises(ValueError, match="syft"):
        make(rpms)


def test_os_release_is_parsed():
    assert sbom.os_release('NAME="ShapeBit"\n# note\nIMAGE_VERSION=dev\n') == {"NAME": "ShapeBit", "IMAGE_VERSION": "dev"}


def test_each_credit_has_an_spdx_license_id():
    # A single ID: the notice links to its page on spdx.org.
    assert all(re.fullmatch(r"[A-Za-z0-9.+-]+", c["license"]) for e in EXTRAS for c in e["credits"])


def test_the_command_line_names_the_image_and_the_directory(monkeypatch):
    calls = []
    monkeypatch.setattr(sbom, "generate", lambda image, directory: calls.append(("generate", image, directory)))
    monkeypatch.setattr(sbom.artifact, "push", lambda ref, kind, title, files: calls.append(("push", ref, files)))
    sbom.main(["generate", "localhost/os:dev", "build/sbom"])
    sbom.main(["push", "build/sbom", "ghcr.io/x/os:1-sbom", "SBOM"])
    assert calls == [("generate", "localhost/os:dev", "build/sbom"), ("push", "ghcr.io/x/os:1-sbom", [
        sbom.pathlib.Path("build/sbom/sbom.spdx.json"), sbom.pathlib.Path("build/sbom/sbom.cdx.json")])]
