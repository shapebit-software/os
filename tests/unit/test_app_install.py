"""desktop/apps/app-install: it tells Flatpak's progress; cancelling it stops
the flatpak under way too, so nothing goes on installing unseen, and removes
what that fetched; and updates remove what no app uses any more."""

import json
import os
import pathlib
import signal
import subprocess
import time

ROOT = pathlib.Path(__file__).parents[2]
APP_INSTALL = ROOT / "desktop" / "apps" / "app-install"

# A flatpak that writes its pid, then installs for a minute; it logs the rest.
FAKE_FLATPAK = """#!/bin/bash
echo "$*" >> "$LOG"
[[ " $* " == *" install "* ]] || exit 0
echo $$ > "$PID_FILE"
exec sleep 60
"""


def alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    # A zombie is gone, waiting only for its parent.
    return pathlib.Path(f"/proc/{pid}/stat").read_text().split()[2] != "Z"


def test_sigterm_stops_the_flatpak_under_way(tmp_path):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    flatpak = bin_dir / "flatpak"
    flatpak.write_text(FAKE_FLATPAK)
    flatpak.chmod(0o755)
    pid_file = tmp_path / "pid"
    log = tmp_path / "log"
    env = {**os.environ, "PATH": f"{bin_dir}:{os.environ['PATH']}", "PID_FILE": str(pid_file), "LOG": str(log)}
    env.pop("DESKTOP_SHELL", None)
    installer = subprocess.Popen([APP_INSTALL, "apps", "org.example.App"], env=env, stdout=subprocess.PIPE, text=True)
    for _ in range(100):
        if pid_file.exists() and pid_file.read_text().strip():
            break
        time.sleep(0.05)
    child = int(pid_file.read_text())
    assert alive(child)

    installer.send_signal(signal.SIGTERM)
    installer.wait(timeout=10)
    for _ in range(100):
        if not alive(child):
            break
        time.sleep(0.05)
    assert not alive(child)
    assert '"done"' not in installer.stdout.read()
    assert log.read_text().splitlines()[-1] == "--user uninstall --unused --noninteractive"


# A flatpak that redraws its progress, as Flatpak does in a terminal, only
# when it is in one.
DRAWING_FLATPAK = r"""#!/bin/bash
[[ " $* " == *" install "* ]] || exit 0
[[ -t 1 ]] || exit 0
printf 'Installing 1/2\xe2\x80\xa6 \e[32m####\e[0m  50%%  1 MB/s\r'
printf 'Installing 1/2\xe2\x80\xa6 \e[32m########\e[0m 100%%  1 MB/s\n'
printf 'Installing 2/2\xe2\x80\xa6 \e[32m####\e[0m  50%%  1 MB/s\r\n'
"""


def test_progress_counts_all_that_flatpak_installs(tmp_path):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    (bin_dir / "flatpak").write_text(DRAWING_FLATPAK)
    (bin_dir / "flatpak").chmod(0o755)
    env = {**os.environ, "PATH": f"{bin_dir}:{os.environ['PATH']}"}
    env.pop("DESKTOP_SHELL", None)
    result = subprocess.run([APP_INSTALL, "apps", "org.example.App"], env=env, capture_output=True, text=True, timeout=30)
    said = [json.loads(line) for line in result.stdout.splitlines()]
    assert [m.get("percent") for m in said if "percent" in m] == [25, 50, 75]
    assert said[-1] == {"done": ["org.example.App"]}


def test_an_update_updates_all_then_removes_what_no_app_uses(tmp_path):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    (bin_dir / "flatpak").write_text('#!/bin/bash\necho "$*" >> "$LOG"\n')
    (bin_dir / "flatpak").chmod(0o755)
    log = tmp_path / "log"
    env = {**os.environ, "PATH": f"{bin_dir}:{os.environ['PATH']}", "LOG": str(log)}
    env.pop("DESKTOP_SHELL", None)
    result = subprocess.run([APP_INSTALL, "update"], env=env, capture_output=True, text=True, timeout=30)
    assert json.loads(result.stdout.splitlines()[-1]) == {"done": "updated"}
    assert log.read_text().splitlines() == ["--user update --noninteractive", "--user uninstall --unused --noninteractive"]
