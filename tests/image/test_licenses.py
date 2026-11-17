"""Required notices must reach the image, not just exist in a build stage. The
committed texts (image/rootfs/usr/share/licenses) are checked in tests/unit."""

import json
import os
import pathlib
import shutil
import subprocess
import tempfile

import pytest


@pytest.mark.parametrize("path,notice", [
    ("shapebit/LICENSE", "Required Notice: Copyright Marcin Syngajewski"),
    ("python3-sherpa-onnx/LICENSE", "Apache License"),
    ("python3-sherpa-onnx/kissfft/COPYING", "Mark Borgerding"),
    ("llama-server/LICENSE-llamafile", "Copyright 2024 Mozilla Foundation"),
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
    text = json.loads(sh("/usr/libexec/desktop/licenses read python3-onnxruntime/ThirdPartyNotices.txt"))
    assert "THIRD PARTY SOFTWARE NOTICES" in text["text"]
    readme = json.loads(sh("/usr/libexec/desktop/licenses read libglvnd/README.md"))
    assert "Permission is hereby granted" in readme["text"]
    assert "kf6-filesystem" in components and "osinfo-db" in components


def test_settings_component_displays_the_local_license():
    # Image checks execute inside the image; the UI needs no test package there.
    with tempfile.TemporaryDirectory() as directory:
        root = pathlib.Path(directory)
        (root / "qs").symlink_to("/usr/share/desktop/shell")
        config = root / "viewer.qml"
        shutil.copyfile(pathlib.Path(__file__).with_name("license-viewer.qml"), config)
        env = {**os.environ, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software",
               "QML_IMPORT_PATH": str(root), "XDG_RUNTIME_DIR": str(root / "runtime"),
               "XDG_CONFIG_HOME": str(root / "config"), "XDG_CACHE_HOME": str(root / "cache")}
        env.pop("DESKTOP_SHELL", None)
        result = subprocess.run(["qs", "-p", str(config)], env=env, capture_output=True, text=True, timeout=25)
        assert result.returncode == 0, result.stdout + result.stderr
        assert "LICENSE_VIEWER_OK" in result.stdout + result.stderr
