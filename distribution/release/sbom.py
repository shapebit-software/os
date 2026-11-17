#!/usr/bin/env python3
"""The software bill of materials of IMAGE, as SPDX 2.3 JSON and CycloneDX 1.6
JSON, with the same content (documentation/License.md).

syft (SYFT_IMAGE) scans the image's filesystem from inside a container of it,
once for both formats: its binary is mounted read-only, the container has no
network, and nothing is installed. It finds the RPMs and the Python packages.
This fails unless syft's RPMs are exactly `rpm -qa`'s, whose source RPMs
distribution/release/sources.py publishes, and adds to both documents what syft cannot see:
ShapeBit itself (its version and revision from the image's os-release), the code
that each RPM declares it bundles (Fedora's `Provides: bundled(...)`, as in
the external packages), and the models that are extras (the image's extras.json), as
optional components.

Usage: sbom.py generate IMAGE DIR    write IMAGE's sbom.spdx.json and sbom.cdx.json to DIR
       sbom.py push DIR REF TITLE    push both as one OCI artifact to REF
ENGINE runs the containers; skopeo copies the artifact.
"""

import argparse
import importlib.util
import json
import os
import pathlib
import re
import shlex
import subprocess
import sys
import tempfile
import urllib.parse

ROOT = pathlib.Path(__file__).resolve().parents[2]
TYPE = "application/vnd.shapebit.sbom.v1"
FILES = {"spdx": "sbom.spdx.json", "cyclonedx": "sbom.cdx.json"}
SHAPEBIT_LICENSE_NAME = "PolyForm Shield License 1.0.0"
SHAPEBIT_LICENSE_URL = "https://polyformproject.org/licenses/shield/1.0.0"
SHAPEBIT_LICENSE = "LicenseRef-PolyForm-Shield-1.0.0"
REPOSITORY = "https://github.com/shapebit-software/os"

spec = importlib.util.spec_from_file_location("artifact", ROOT / "distribution/release/artifact.py")
artifact = importlib.util.module_from_spec(spec)
spec.loader.exec_module(artifact)


def engine():
    return shlex.split(os.environ["ENGINE"])


def os_release(text):
    return {key: value.strip('"') for key, _, value in
            (line.partition("=") for line in text.splitlines()) if key and not key.startswith("#")}


def spdx_id(*parts):
    return "SPDXRef-" + re.sub(r"[^A-Za-z0-9.-]+", "-", "-".join(parts)).strip("-")


def package(ident, name, version, license, location, supplier=None, purl=None, comment=None):
    result = {
        "SPDXID": ident, "name": name, "versionInfo": version,
        "downloadLocation": location, "filesAnalyzed": False,
        "licenseConcluded": "NOASSERTION", "licenseDeclared": license,
        "copyrightText": "NOASSERTION",
        "supplier": f"Organization: {supplier}" if supplier else "NOASSERTION",
    }  # fmt: skip
    if purl:
        result["externalRefs"] = [{"referenceCategory": "PACKAGE-MANAGER", "referenceType": "purl",
                                   "referenceLocator": purl}]
    if comment:
        result["comment"] = comment
    return result


def bundled(lines):
    """{RPM: [(library, version)]}: the code each RPM declares it bundles, from
    `rpm -qa` lines of NAME, PROVIDENAME, PROVIDEVERSION. A crate's features are
    the crate."""
    result = {}
    for line in lines.splitlines():
        package, name, version = line.split("\t")
        if match := re.fullmatch(r"bundled\((.+)\)", name):
            library = re.sub(r"^crate\(([^/]+)/.*\)$", r"crate(\1)", match[1])
            result.setdefault(package, set()).add((library, version))
    return {package: sorted(libraries) for package, libraries in result.items()}


def installed(lines):
    """The names of the installed RPMs, from the same `rpm -qa` lines; gpg-pubkey
    is rpm's record of an imported key, not a package."""
    return {line.split("\t")[0] for line in lines.splitlines()} - {"gpg-pubkey"}


def bundled_purl(library, version):
    match = re.fullmatch(r"(crate|golang)\((.+)\)", library)
    if match and version:
        return f"pkg:{'cargo' if match[1] == 'crate' else 'golang'}/{match[2]}@{version}"
    return None


def rpm_name(purl):
    """The name of an RPM from the RPM database, which names its source RPM
    (upstream=); None for syft's entries from the package notes of binaries,
    which are not installed RPMs, and for anything else."""
    if purl and purl.startswith("pkg:rpm/") and "upstream=" in purl:
        return urllib.parse.unquote(purl.split("/")[2].split("@")[0])
    return None


def check(found, rpm_names):
    """Fail unless FOUND, syft's RPMs, are exactly RPM_NAMES, the image's."""
    if missed := sorted(rpm_names - found):
        raise ValueError(f"syft did not find the RPMs {', '.join(missed)}")
    if unknown := sorted(found - rpm_names):
        raise ValueError(f"syft found RPMs that are not installed: {', '.join(unknown)}")


def additions(release, extras, bundles):
    """What syft cannot see, for both formats: each with a key, its fields, and
    `parent`, the RPM that bundles it, or `optional` for a model."""
    version, revision = release["IMAGE_VERSION"], release["IMAGE_REVISION"]
    items = [{"key": ("shapebit",), "name": "ShapeBit OS", "version": version, "license": SHAPEBIT_LICENSE,
              "location": f"git+{REPOSITORY}@{revision}",
              "comment": "The desktop, the installer, and the system's configuration."}]
    for parent, libraries in bundles.items():
        for library, library_version in libraries:
            items.append({"key": ("bundled", parent, library, library_version), "name": library,
                          "version": library_version or None, "purl": bundled_purl(library, library_version),
                          "parent": parent, "comment": f"Bundled in the RPM {parent}; its license is among the RPM's."})
    for extra in extras:
        for credit in extra["credits"]:
            items.append({"key": ("extra", extra["id"], credit["work"]), "name": credit["work"],
                          "license": credit["license"], "location": credit["url"], "supplier": credit["by"],
                          "optional": True, "comment": f"Downloaded on request as the extra {extra['name']!r}"
                          + (f"; {credit['changes']}." if "changes" in credit else ".")})
    return items


def to_spdx(doc, items, rpm_names, license_text):
    """ITEMS added to syft's SPDX document."""
    packages = doc["packages"]
    rpms = {}
    for p in packages:
        for ref in p.get("externalRefs", []):
            if ref["referenceType"] == "purl" and (name := rpm_name(ref["referenceLocator"])):
                rpms.setdefault(name, p["SPDXID"])
    check(rpms.keys(), rpm_names)
    root = next(r["relatedSpdxElement"] for r in doc["relationships"]
                if r["spdxElementId"] == "SPDXRef-DOCUMENT" and r["relationshipType"] == "DESCRIBES")
    shapebit = spdx_id("Package", *items[0]["key"])
    for item in items:
        ident = spdx_id("Package", *item["key"])
        packages.append(package(ident, item["name"], item.get("version") or "NOASSERTION",
                                item.get("license", "NOASSERTION"), item.get("location", "NOASSERTION"),
                                supplier=item.get("supplier"), purl=item.get("purl"), comment=item["comment"]))
        if item.get("optional"):
            relation = (ident, "OPTIONAL_COMPONENT_OF", shapebit)
        else:
            relation = (rpms[item["parent"]] if "parent" in item else root, "CONTAINS", ident)
        doc["relationships"].append(dict(zip(("spdxElementId", "relationshipType", "relatedSpdxElement"), relation)))
    doc.setdefault("hasExtractedLicensingInfos", []).append({
        "licenseId": SHAPEBIT_LICENSE, "name": SHAPEBIT_LICENSE_NAME, "extractedText": license_text,
        "seeAlsos": [SHAPEBIT_LICENSE_URL],
    })  # fmt: skip
    doc["creationInfo"]["creators"].append("Tool: shapebit-sbom")
    return doc


def to_cyclonedx(doc, items, rpm_names, license_text):
    """ITEMS added to syft's CycloneDX document: bundled code nested in the
    component of its RPM, models with the scope "optional"."""
    components = doc.setdefault("components", [])
    rpms = {}
    for c in components:
        if name := rpm_name(c.get("purl")):
            rpms.setdefault(name, c)
    check(rpms.keys(), rpm_names)
    for item in items:
        component = {"bom-ref": "shapebit:" + ":".join(item["key"]),
                     "type": "machine-learning-model" if item.get("optional") else "library",
                     "name": item["name"], "description": item["comment"]}
        for field in ("version", "purl"):
            if item.get(field):
                component[field] = item[field]
        if item.get("supplier"):
            component["supplier"] = {"name": item["supplier"]}
        if item.get("license") == SHAPEBIT_LICENSE:
            component["licenses"] = [{"license": {"name": SHAPEBIT_LICENSE_NAME, "url": SHAPEBIT_LICENSE_URL,
                                                  "text": {"content": license_text}}}]
        elif item.get("license"):
            component["licenses"] = [{"expression": item["license"]}]
        if item.get("location"):
            kind = "vcs" if item["location"].startswith("git+") else "distribution"
            component["externalReferences"] = [{"type": kind, "url": item["location"].removeprefix("git+")}]
        if item.get("optional"):
            component["scope"] = "optional"
        if "parent" in item:
            rpms[item["parent"]].setdefault("components", []).append(component)
        else:
            components.append(component)
    tools = doc.setdefault("metadata", {}).setdefault("tools", {})
    if isinstance(tools, dict):
        tools.setdefault("components", []).append({"type": "application", "name": "shapebit-sbom"})
    return doc


def image_run(image, command, *args):
    return subprocess.run([*engine(), "run", "--rm", "--network", "none", "--entrypoint", command, image, *args],
                          check=True, capture_output=True, text=True).stdout


def image_file(image, path):
    return image_run(image, "cat", path)


def scan(image, version):
    """syft's SPDX and CycloneDX documents of IMAGE's filesystem, from one scan
    inside a container of it."""
    with tempfile.TemporaryDirectory() as tool:
        container = subprocess.run([*engine(), "create", os.environ["SYFT_IMAGE"]],
                                   check=True, capture_output=True, text=True).stdout.strip()
        try:
            subprocess.run([*engine(), "cp", f"{container}:/syft", f"{tool}/syft"], check=True)
        finally:
            subprocess.run([*engine(), "rm", container], check=True, capture_output=True)
        # Writable to the container's user, whom a rootless engine maps to another.
        os.chmod(tool, 0o777)
        excluded = [arg for path in ("proc", "sys", "dev", "run", "tmp", "sbom-tool")
                    for arg in ("--exclude", f"./{path}/**")]
        subprocess.run([
            *engine(), "run", "--rm", "--network", "none", "-v", f"{tool}:/sbom-tool:z",
            "-e", "HOME=/tmp", "-e", "SYFT_CHECK_FOR_APP_UPDATE=false", "--entrypoint", "/sbom-tool/syft",
            image, "dir:/", *excluded, "--source-name", "shapebit-os", "--source-version", version,
            "-o", "spdx-json=/sbom-tool/spdx.json", "-o", "cyclonedx-json=/sbom-tool/cyclonedx.json", "-q",
        ], check=True)  # fmt: skip
        return {kind: json.loads((pathlib.Path(tool) / f"{kind}.json").read_text()) for kind in FILES}


def generate(image, directory):
    for name in ("ENGINE", "SYFT_IMAGE"):
        if not os.environ.get(name):
            sys.exit(f"error: {name} is not set")
    release = os_release(image_file(image, "/usr/lib/os-release"))
    license_text = image_file(image, "/usr/share/licenses/shapebit/LICENSE")
    # Each installed RPM provides at least itself, so this lists every one.
    provides = image_run(image, "rpm", "-qa", "--qf", "[%{=NAME}\t%{PROVIDENAME}\t%{PROVIDEVERSION}\n]")
    items = additions(release, json.loads(image_file(image, "/usr/share/desktop/extras.json")), bundled(provides))
    docs = scan(image, release["IMAGE_VERSION"])
    docs = {"spdx": to_spdx(docs["spdx"], items, installed(provides), license_text),
            "cyclonedx": to_cyclonedx(docs["cyclonedx"], items, installed(provides), license_text)}
    directory = pathlib.Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    for kind, doc in docs.items():
        (directory / FILES[kind]).write_text(json.dumps(doc, indent=1) + "\n")
    print(f"{directory}: {len(docs['spdx']['packages'])} SPDX packages, {len(docs['cyclonedx']['components'])} CycloneDX components")


def main(argv):
    parser = argparse.ArgumentParser(usage=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    command = commands.add_parser("generate")
    command.add_argument("image")
    command.add_argument("directory")
    command = commands.add_parser("push")
    command.add_argument("directory")
    command.add_argument("ref")
    command.add_argument("title")
    args = parser.parse_args(argv)
    if args.command == "generate":
        generate(args.image, args.directory)
    else:
        artifact.push(args.ref, TYPE, args.title, [pathlib.Path(args.directory) / name for name in FILES.values()])


if __name__ == "__main__":
    main(sys.argv[1:])
