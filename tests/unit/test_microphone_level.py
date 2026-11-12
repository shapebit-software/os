"""desktop/session/microphone-level: the peak of each tenth of a second, from 0
to 1, with a made-up recorder; it names its stream, which the shell then
counts as no one recording."""

import os
import pathlib
import struct
import subprocess

LEVEL = pathlib.Path(__file__).parents[2] / "desktop" / "session" / "microphone-level"


def test_each_tenth_of_a_second_is_its_peak(tmp_path):
    # Three tenths at 8 kHz: silence, a loud peak, and one past full.
    samples = [0] * 800 + [6000, -3000] * 400 + [-32768] * 800
    (tmp_path / "audio").write_bytes(struct.pack(f"<{len(samples)}h", *samples))
    recorder = tmp_path / "pw-record"
    recorder.write_text(f'#!/bin/bash\necho "$@" > "{tmp_path}/args"\ncat "{tmp_path}/audio"\n')
    recorder.chmod(0o755)
    done = subprocess.run([LEVEL], capture_output=True, text=True, timeout=10,
                          env={**os.environ, "PATH": f"{tmp_path}:{os.environ['PATH']}"})  # fmt: skip
    assert done.stdout.split() == ["0.00", "0.50", "1.00"]
    assert 'node.name = "microphone-level"' in (tmp_path / "args").read_text()
