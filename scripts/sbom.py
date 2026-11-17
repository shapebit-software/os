#!/usr/bin/env python3
"""The software bill of materials of IMAGE, in SPDX 2.3 JSON (docs/License.md).

syft (SYFT_IMAGE) scans the image's filesystem from inside a container of it:
its binary is mounted read-only, the container has no network, and nothing is
installed. It finds the RPMs and the Python packages. This adds what it cannot
see, from what the repository pins, and fails unless syft's RPMs are exactly
`rpm -qa`'s, whose source RPMs scripts/sources.py publishes: ShapeBit itself (its version and revision
from the image's os-release), the
code that each RPM declares it bundles (Fedora's `Provides: bundled(...)`, as in
third-party/), and the models that are extras (the image's extras.json), as optional
components.

Usage: sbom.py generate IMAGE FILE    write IMAGE's SBOM to FILE
       sbom.py push FILE REF TITLE    push FILE as an OCI artifact to REF
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

ROOT = pathlib.Path(__file__).resolve().parent.parent
TYPE = "application/spdx+json"
SHAPEBIT_LICENSE = "LicenseRef-PolyForm-Shield-1.0.0"
REPOSITORY = "https://github.com/shapebit-software/os"

spec = importlib.util.spec_from_file_location("artifact", ROOT / "scripts/artifact.py")
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


def complete(doc, release, license_text, extras, rpm_names, bundles):
    """Add to syft's document what it cannot see; fail unless its RPMs are exactly
    RPM_NAMES, the image's, whose source RPMs are its published sources."""
    packages = doc["packages"]
    rpms = {}
    # An RPM from the RPM database names its source RPM (upstream=); syft's
    # entries from the package notes of binaries do not, and are not installed RPMs.
    for p in packages:
        for ref in p.get("externalRefs", []):
            purl = ref["referenceLocator"]
            if ref["referenceType"] == "purl" and purl.startswith("pkg:rpm/") and "upstream=" in purl:
                rpms.setdefault(urllib.parse.unquote(purl.split("/")[2].split("@")[0]), p["SPDXID"])
    if missed := sorted(rpm_names - rpms.keys()):
        raise ValueError(f"syft did not find the RPMs {', '.join(missed)}")
    if unknown := sorted(rpms.keys() - rpm_names):
        raise ValueError(f"syft found RPMs that are not installed: {', '.join(unknown)}")
    root = next(r["relatedSpdxElement"] for r in doc["relationships"]
                if r["spdxElementId"] == "SPDXRef-DOCUMENT" and r["relationshipType"] == "DESCRIBES")

    def add(item, relation, of):
        packages.append(item)
        doc["relationships"].append({"spdxElementId": of, "relationshipType": relation,
                                     "relatedSpdxElement": item["SPDXID"]})

    version, revision = release["IMAGE_VERSION"], release["IMAGE_REVISION"]
    shapebit = package(spdx_id("Package-shapebit"), "ShapeBit OS", version, SHAPEBIT_LICENSE,
                       f"git+{REPOSITORY}@{revision}",
                       comment="The desktop, the installer, and the system's configuration.")
    add(shapebit, "CONTAINS", root)
    doc.setdefault("hasExtractedLicensingInfos", []).append({
        "licenseId": SHAPEBIT_LICENSE, "name": "PolyForm Shield License 1.0.0", "extractedText": license_text,
        "seeAlsos": ["https://polyformproject.org/licenses/shield/1.0.0"],
    })  # fmt: skip
    for parent, libraries in bundles.items():
        for library, library_version in libraries:
            add(package(spdx_id("Package-bundled", parent, library, library_version), library,
                        library_version or "NOASSERTION", "NOASSERTION", "NOASSERTION",
                        purl=bundled_purl(library, library_version),
                        comment=f"Bundled in the RPM {parent}; its license is among the RPM's."),
                "CONTAINS", rpms[parent])
    for extra in extras:
        for credit in extra["credits"]:
            item = package(spdx_id("Package-extra", extra["id"], credit["work"]), credit["work"], "NOASSERTION",
                           credit["license"], credit["url"], supplier=credit["by"],
                           comment=f"Downloaded on request as the extra {extra['name']!r}"
                           + (f"; {credit['changes']}." if "changes" in credit else "."))
            packages.append(item)
            doc["relationships"].append({"spdxElementId": item["SPDXID"], "relationshipType": "OPTIONAL_COMPONENT_OF",
                                         "relatedSpdxElement": shapebit["SPDXID"]})
    doc["creationInfo"]["creators"].append("Tool: shapebit-sbom")
    return doc


def image_run(image, command, *args):
    return subprocess.run([*engine(), "run", "--rm", "--network", "none", "--entrypoint", command, image, *args],
                          check=True, capture_output=True, text=True).stdout


def image_file(image, path):
    return image_run(image, "cat", path)


def scan(image, version):
    """syft's SPDX document of IMAGE's filesystem, scanned from inside a container of it."""
    with tempfile.TemporaryDirectory() as tool:
        container = subprocess.run([*engine(), "create", os.environ["SYFT_IMAGE"]],
                                   check=True, capture_output=True, text=True).stdout.strip()
        try:
            subprocess.run([*engine(), "cp", f"{container}:/syft", f"{tool}/syft"], check=True)
        finally:
            subprocess.run([*engine(), "rm", container], check=True, capture_output=True)
        # Readable to the container's user, whom a rootless engine maps to another.
        os.chmod(tool, 0o755)
        excluded = [arg for path in ("proc", "sys", "dev", "run", "tmp", "sbom-tool")
                    for arg in ("--exclude", f"./{path}/**")]
        return json.loads(subprocess.run([
            *engine(), "run", "--rm", "--network", "none", "-v", f"{tool}:/sbom-tool:ro,z",
            "-e", "HOME=/tmp", "-e", "SYFT_CHECK_FOR_APP_UPDATE=false", "--entrypoint", "/sbom-tool/syft",
            image, "dir:/", *excluded, "--source-name", "shapebit-os", "--source-version", version,
            "-o", "spdx-json", "-q",
        ], check=True, capture_output=True, text=True).stdout)  # fmt: skip


def generate(image, out):
    for name in ("ENGINE", "SYFT_IMAGE"):
        if not os.environ.get(name):
            sys.exit(f"error: {name} is not set")
    release = os_release(image_file(image, "/usr/lib/os-release"))
    # Each installed RPM provides at least itself, so this lists every one.
    provides = image_run(image, "rpm", "-qa", "--qf", "[%{=NAME}\t%{PROVIDENAME}\t%{PROVIDEVERSION}\n]")
    doc = complete(scan(image, release["IMAGE_VERSION"]), release,
                   image_file(image, "/usr/share/licenses/shapebit/LICENSE"),
                   json.loads(image_file(image, "/usr/share/desktop/extras.json")),
                   installed(provides), bundled(provides))
    out = pathlib.Path(out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(doc, indent=1) + "\n")
    print(f"{out}: {len(doc['packages'])} packages")


def main(argv):
    parser = argparse.ArgumentParser(usage=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    command = commands.add_parser("generate")
    command.add_argument("image")
    command.add_argument("file")
    command = commands.add_parser("push")
    command.add_argument("file")
    command.add_argument("ref")
    command.add_argument("title")
    args = parser.parse_args(argv)
    if args.command == "generate":
        generate(args.image, args.file)
    else:
        artifact.push(args.ref, TYPE, args.title, [args.file])


if __name__ == "__main__":
    main(sys.argv[1:])
