"""Required notices must reach the image, not just exist in a build stage. The
committed texts (packages/release, packages/font) are checked beside them."""

import json

import pytest

pytestmark = pytest.mark.system_image


@pytest.mark.parametrize("path,notice", [
    ("shapebit/LICENSE-GPL-3.0-or-later.txt", "GNU GENERAL PUBLIC LICENSE"),
    ("python3-sherpa-onnx/kissfft/COPYING", "Mark Borgerding"),
    ("llama-server/LICENSE-llamafile", "Copyright 2024 Mozilla Foundation"),
    ("exiv2-libs/COPYING", "GNU GENERAL PUBLIC LICENSE"),
    ("libdrm/NOTICE", "Precision Insight"),
    ("libatasmart/NOTICE", "Lennart Poettering"),
    ("lsof/COPYING", "Purdue Research Foundation"),
    ("WALinuxAgent-udev/NOTICE", "Microsoft"),
    ("exiv2-libs/COPYING-XMPSDK", "Adobe Systems Incorporated"),
    ("glx-utils/NOTICE-glxgears", "Brian Paul"),
    ("glx-utils/NOTICE-glxinfo", "Brian Paul"),
    ("mesa-libGLU/NOTICE-SGI", "Silicon Graphics"),
    ("xcb-util-keysyms/COPYING", "Ulrich Eckhardt"),
    ("xorg-x11-server-Xwayland/COPYING", "Oracle"),
    ("sound-theme-freedesktop/CREDITS", "Ivica Bukvic"),
    ("malcontent-libs/LICENSES/LGPL-2.1-or-later.txt", "GNU LESSER GENERAL PUBLIC LICENSE"),
])
def test_required_component_notice_is_installed(host, path, notice):
    assert notice in host.file("/usr/share/licenses/" + path).content_string


def test_the_collected_notices_are_a_package_under_the_licenses_they_are_for(host, sh):
    assert host.run("rpm -V --nomtime shapebit-licenses").rc == 0
    files = sh("rpm -qL shapebit-licenses").split()
    assert "/usr/share/licenses/xorg-x11-server-Xwayland/COPYING" in files
    license = sh("rpm -q --qf '%{LICENSE}' shapebit-licenses")
    assert sh("rpm -q --qf '%{LICENSE}' xorg-x11-server-Xwayland") in license


def test_all_rpm_license_paths_are_readable(sh):
    sh("""python3 - <<'PY'
import pathlib, subprocess
query = '[%{FILENAMES}\\t%{FILEFLAGS:fflags}\\n]'
for line in subprocess.check_output(['rpm', '-qa', '--qf', query], text=True).splitlines():
    name, flags = line.split('\\t')
    if 'l' in flags:
        path = pathlib.Path(name)
        assert path.is_file() and path.read_bytes().strip(), name
PY""")


def test_each_extra_has_its_license_texts_before_it_is_downloaded(sh):
    sh("""python3 - <<'PY'
import json, pathlib
for entry in json.load(open('/usr/share/desktop/extras.json')):
    assert entry['licenses']
    for name in entry['licenses']:
        assert pathlib.Path('/usr/share/licenses', name).read_text().strip(), name
PY""")


def test_settings_can_read_shared_and_collected_notices(sh):
    result = json.loads(sh("/usr/libexec/desktop/licenses list"))
    assert not result.get("error")
    components = {c["name"]: c for c in result["components"]}
    assert {"shapebit", "llama-server", "python3-sherpa-onnx", "parakeet", "gemma-4-e2b", "python3-onnxruntime"} <= components.keys()
    for component in components.values():
        assert all(not f["name"].startswith(".") for f in component["files"])
    # sherpa-onnx's own license is in its Python metadata, which the RPM database knows.
    sherpa = json.loads(sh("/usr/libexec/desktop/licenses read python3-sherpa-onnx/LICENSE"))
    assert "Apache License" in sherpa["text"]
    text = json.loads(sh("/usr/libexec/desktop/licenses read python3-onnxruntime/ThirdPartyNotices.txt"))
    assert "THIRD PARTY SOFTWARE NOTICES" in text["text"]
    readme = json.loads(sh("/usr/libexec/desktop/licenses read libglvnd/README.md"))
    assert "Permission is hereby granted" in readme["text"]
    assert "kf6-filesystem" in components and "osinfo-db" in components


def test_settings_component_displays_the_local_license(host):
    # The viewer is one of the checks' files, which the container has
    # read-only; the UI needs no test package in the image. In a copy of the
    # shell's folders: Quickshell resolves `qs.` imports from the folder of the
    # file it runs.
    result = host.run(
        'root=$(mktemp -d) && ln -s /usr/share/desktop/shell/*/ "$root/" && '
        'cp /packages/licenses/tests/system/data/viewer.qml "$root/viewer.qml" && '
        'env QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML_IMPORT_PATH="$root" '
        'XDG_RUNTIME_DIR="$root/runtime" XDG_CONFIG_HOME="$root/config" XDG_CACHE_HOME="$root/cache" '
        'timeout 25 qs -p "$root/viewer.qml"')
    assert result.rc == 0, result.stdout + result.stderr
    assert "LICENSE_VIEWER_OK" in result.stdout + result.stderr


# Packages that need no license text: nothing in them is a copyrightable work
# (folders, links, keys, repository settings, metadata).
NOTHING_TO_LICENSE = {
    "default-fonts-core-sans", "desktop-backgrounds-compat", "efi-filesystem", "emacs-filesystem",
    "fedora-gpg-keys", "fedora-repos", "fedora-repos-archive", "filesystem", "fonts-filesystem",
    "kde-filesystem", "libreport-filesystem", "qt6-filesystem",
}
@pytest.fixture(scope="module")
def shapebits(sh):
    """ShapeBit's own packages (packages/, vendor ShapeBit): the texts of their
    licenses are in /usr/share/licenses/shapebit, which Settings > Licenses
    lists once, as "shapebit"; each carries those its License names (below)."""
    lines = sh("rpm -qa --qf '%{NAME} %{VENDOR}\\n'").splitlines()
    return {line.split()[0] for line in lines if line.endswith(" ShapeBit")}


# The texts of ShapeBit's own licenses, by SPDX ID (packaging's package.macros).
OWN = {"GPL-3.0-or-later": "LICENSE-GPL-3.0-or-later.txt", "LGPL-3.0-or-later": "LICENSE-LGPL-3.0-or-later.txt",
       "MIT": "LICENSE-MIT.txt", "CC-BY-SA-4.0": "LICENSE-CC-BY-SA-4.0.txt",
       "LicenseRef-ShapeBit-Brand": "LICENSE-ShapeBit-Brand.txt"}


def test_every_own_package_carries_its_licenses(sh, shapebits):
    # Each text is one file for all, which rpm lets them own together; the
    # font is Instrument Sans, under the OFL.
    assert shapebits
    for name in shapebits:
        texts = sh("rpm -qL %s", name).split()
        license = sh("rpm -q --qf '%%{LICENSE}' %s", name)
        expected = {f"/usr/share/licenses/shapebit/{OWN[i]}" for i in license.split(" AND ") if i in OWN}
        if name == "shapebit-font":
            expected = {"/usr/share/licenses/instrument-sans/OFL.txt"}
        assert expected and expected <= set(texts), name


def test_brand_artwork_comes_with_the_brands_terms(sh):
    # No open license covers the logo (LICENSES/LicenseRef-ShapeBit-Brand.txt);
    # the boot splash's watermark is the logo. The installer is only on the medium.
    assert "/usr/share/licenses/shapebit/LICENSE-ShapeBit-Brand.txt" in sh("rpm -qL shapebit-splash").split()
    assert "LicenseRef-ShapeBit-Brand" in sh("rpm -q --qf '%{LICENSE}' shapebit-splash")


def test_every_installed_package_has_its_license_text(sh, shapebits):
    # Settings > Licenses lists a package, or a package of the same source, for
    # each text it finds; a package that is in neither has no text in the image.
    listed = {c["name"] for c in json.loads(sh("/usr/libexec/desktop/licenses list"))["components"]}
    sources = {}
    for line in sh("rpm -qa --qf '%{NAME}\\t%{SOURCERPM}\\n'").splitlines():
        name, source = line.split("\t")
        sources.setdefault(source, set()).add(name)
    without = {name for names in sources.values() if not names & listed for name in names} - {"gpg-pubkey"}
    assert "shapebit" in listed
    assert without - NOTHING_TO_LICENSE - shapebits == set()
