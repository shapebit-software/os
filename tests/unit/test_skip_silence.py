"""desktop/capture/skip-silence: which pieces of a recording it keeps, and, with
ffmpeg, that a voice and a camera recording come out shorter in their own
format, or stay as they are."""

import importlib.machinery
import importlib.util
import pathlib
import shutil
import subprocess

import numpy
import pytest

SKIP = pathlib.Path(__file__).parents[2] / "desktop" / "capture" / "skip-silence"

loader = importlib.machinery.SourceFileLoader("skip_silence", str(SKIP))
spec = importlib.util.spec_from_loader("skip_silence", loader)
skip = importlib.util.module_from_spec(spec)
loader.exec_module(skip)


def speech_and_silence(*parts):
    """Frame levels in dB: (seconds, dB) parts, 50 frames a second."""
    return numpy.concatenate([numpy.full(int(seconds * 50), float(db)) for seconds, db in parts])


def test_silence_is_measured_against_the_recordings_own_noise():
    # Noise at -30 dB, louder than a fixed threshold would allow, and speech at -10.
    loud = speech_and_silence((2, -10), (3, -30), (2, -10))
    assert skip.silences(loud) == [(2.0, 5.0)]


def test_short_pauses_stay():
    assert skip.silences(speech_and_silence((2, -10), (0.5, -40), (2, -10))) == []


def test_steady_sound_has_no_silence():
    # Noise alone, or speech throughout: nothing stands out to cut.
    assert skip.silences(speech_and_silence((3, -30), (3, -27))) == []


def test_digital_silence_counts_as_quiet():
    loud = speech_and_silence((1, -20), (2, -180), (1, -20))
    assert skip.silences(loud) == [(1.0, 3.0)]


def test_levels_ignore_a_click_inside_a_silence():
    samples = numpy.zeros(16000, dtype=numpy.int16)
    samples[8000:8320] = 20000
    assert (skip.levels(samples) < -100).all()


def test_silence_shrinks_to_the_pause():
    assert skip.kept([(2.0, 5.0)], 7.0, pause=0.4) == [(0.0, 2.2), (4.8, 7.0)]


def test_silence_at_the_start_and_end_is_cut_to_half_the_pause_inside():
    assert skip.kept([(0.0, 1.0), (4.0, 6.0)], 6.0, pause=0.4) == [(0.8, 4.2)]


def test_no_silence_keeps_everything():
    assert skip.kept([], 6.0) == [(0.0, 6.0)]


def test_all_silence_keeps_nothing():
    assert skip.kept([(0.0, 6.0)], 6.0) == []


def test_graph_joins_sound_alone_or_with_video():
    audio = skip.graph([(0, 1), (2, 3)], video=False)
    assert "asplit=2[a0][a1]" in audio and "concat=n=2:v=0:a=1[a]" in audio and "[0:v]" not in audio
    video = skip.graph([(0, 1), (2, 3)], video=True)
    assert "split=2[v0][v1]" in video and "[v0t][a0t][v1t][a1t]concat=n=2:v=1:a=1[v][a]" in video


ffmpeg = pytest.mark.skipif(not shutil.which("ffmpeg"), reason="ffmpeg is missing: install ffmpeg-free")


def make(path, inputs, *codecs):
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", *inputs, *codecs, str(path)], check=True)


def length(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
                         capture_output=True, text=True, check=True).stdout
    return float(out)


@ffmpeg
def test_voice_recording_loses_its_silence(tmp_path):
    voice = tmp_path / "Voice.opus"
    make(voice, ["-f", "lavfi", "-i", "sine=d=2,apad=pad_dur=3", "-f", "lavfi", "-i", "sine=d=2",
                 "-filter_complex", "[0][1]concat=n=2:v=0:a=1"], "-c:a", "libopus", "-ac", "1")
    subprocess.run([SKIP, voice], check=True)
    assert length(voice) == pytest.approx(4.4, abs=0.15)
    assert [p.name for p in tmp_path.iterdir()] == ["Voice.opus"]


@ffmpeg
def test_camera_recording_loses_its_silence_and_stays_webm(tmp_path):
    video = tmp_path / "Video.webm"
    make(video, ["-f", "lavfi", "-i", "testsrc=s=160x120:r=15:d=6", "-f", "lavfi", "-i", "sine=d=2,apad=pad_dur=4",
                 "-t", "6"], "-c:v", "libvpx-vp9", "-deadline", "realtime", "-c:a", "libopus")
    subprocess.run([SKIP, video], check=True)
    assert length(video) == pytest.approx(2.2, abs=0.2)
    streams = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "stream=codec_name", "-of", "csv=p=0", str(video)],
                             capture_output=True, text=True, check=True).stdout.split()
    assert streams == ["vp9", "opus"]


@ffmpeg
def test_noisy_microphone_still_loses_its_silence(tmp_path):
    # A regression: room noise around -28 dB hid every silence from a fixed -35 dB threshold.
    voice = tmp_path / "Voice.opus"
    make(voice, ["-f", "lavfi", "-i", "anoisesrc=a=0.07:d=7", "-f", "lavfi", "-i", "sine=d=2,volume=4",
                 "-f", "lavfi", "-i", "sine=d=2,volume=4", "-filter_complex",
                 "[1]apad=pad_dur=3[s];[s][2]concat=n=2:v=0:a=1[v];[0][v]amix=inputs=2:normalize=0"],
         "-c:a", "libopus", "-ac", "1")
    subprocess.run([SKIP, voice], check=True)
    assert length(voice) < 5.5


@ffmpeg
def test_recording_without_silence_is_untouched(tmp_path):
    voice = tmp_path / "Voice.opus"
    make(voice, ["-f", "lavfi", "-i", "sine=d=3"], "-c:a", "libopus")
    before = voice.read_bytes()
    subprocess.run([SKIP, voice], check=True)
    assert voice.read_bytes() == before


def test_missing_recording_fails_and_writes_nothing(tmp_path):
    result = subprocess.run([SKIP, tmp_path / "gone.opus"], capture_output=True, check=False,
                            env={"PATH": "/usr/bin:/bin"})
    assert result.returncode != 0
    assert not list(tmp_path.iterdir())
