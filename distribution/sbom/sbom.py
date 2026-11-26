"""The software bill of materials of IMAGE, as SPDX 2.3 JSON (distribution/sbom/README.md).

syft (SYFT_IMAGE, pinned by digest) scans the image's filesystem from inside a container of it:
its binary is mounted read-only, the container has no network, and nothing is
installed. syft cannot read the archive that Docker saves, whose index nests
another. It finds the RPMs and the Python packages. This fails
unless syft's RPMs are exactly `rpm -qa`'s, whose source RPMs
../sources/sources.py collects, and adds to the document what syft cannot see:
ShapeBit itself (its version and revision from the image's os-release), the code
that each RPM declares it bundles (Fedora's `Provides: bundled(...)`, as in
the external packages), and the models that are extras (the image's extras.json), as
optional components.

generate() writes IMAGE's sbom.spdx.json to a directory; distribution/release.py
pushes it as an OCI artifact. ENGINE runs the containers.
"""

import json
import os
import pathlib
import re
import shlex
import subprocess
import sys
import tempfile
import urllib.parse

TYPE = "application/vnd.shapebit.sbom.v1"
FILE = "sbom.spdx.json"
# ShapeBit's own licenses in the image, by kind of file (REUSE.toml): programs,
# the QML module Colors, configuration, and the brand artwork, in the installer
# and the boot splash, under the terms the image ships as BRAND_FILE.
BRAND = "LicenseRef-ShapeBit-Brand"
BRAND_FILE = "/usr/share/licenses/shapebit/LICENSE-ShapeBit-Brand.txt"
SHAPEBIT_LICENSE = f"GPL-3.0-or-later AND LGPL-3.0-or-later AND MIT AND {BRAND}"
REPOSITORY = "https://github.com/shapebit-software/os"
SYFT_IMAGE = "docker.io/anchore/syft:v1.18.1@sha256:b8c170b8e51bfc4779ec3ef4399942c57290f5ce76a9c3af564c9d00d4946a6b"



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
    """What syft cannot see: each with a key, its fields, and
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


def to_spdx(doc, items, rpm_names, brand):
    """ITEMS added to syft's SPDX document, and BRAND, the text of the brand's
    terms, as SPDX requires of a LicenseRef: in place of any text syft gave it."""
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
    infos = [i for i in doc.get("hasExtractedLicensingInfos", []) if i["licenseId"] != BRAND]
    doc["hasExtractedLicensingInfos"] = [*infos, {"licenseId": BRAND, "name": "ShapeBit brand artwork",
                                                  "extractedText": brand}]
    doc["creationInfo"]["creators"].append("Tool: shapebit-sbom")
    return doc


def image_run(image, command, *args):
    return subprocess.run([*engine(), "run", "--rm", "--network", "none", "--entrypoint", command, image, *args],
                          check=True, capture_output=True, text=True).stdout


def image_file(image, path):
    return image_run(image, "cat", path)


def scan(image, version, work):
    """syft's SPDX document of IMAGE's filesystem, scanned inside a container of
    it. syft waits in WORK, which the engine mounts: a folder of the
    repository, at the same path in the development image and on the host."""
    with tempfile.TemporaryDirectory(dir=work) as tool:
        container = subprocess.run([*engine(), "create", SYFT_IMAGE],
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
            "-o", "spdx-json=/sbom-tool/spdx.json", "-q",
        ], check=True)  # fmt: skip
        return json.loads((pathlib.Path(tool) / "spdx.json").read_text())


def generate(image, directory):
    if not os.environ.get("ENGINE"):
        sys.exit("error: ENGINE is not set")
    directory = pathlib.Path(directory).resolve()
    directory.mkdir(parents=True, exist_ok=True)
    release = os_release(image_file(image, "/usr/lib/os-release"))
    # Each installed RPM provides at least itself, so this lists every one.
    provides = image_run(image, "rpm", "-qa", "--qf", "[%{=NAME}\t%{PROVIDENAME}\t%{PROVIDEVERSION}\n]")
    items = additions(release, json.loads(image_file(image, "/usr/share/desktop/extras.json")), bundled(provides))
    doc = to_spdx(scan(image, release["IMAGE_VERSION"], directory), items, installed(provides),
                  image_file(image, BRAND_FILE))
    (directory / FILE).write_text(json.dumps(doc, indent=1) + "\n")
    print(f"{directory / FILE}: {len(doc['packages'])} packages")
