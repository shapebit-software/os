"""desktop/capture/camera: which format and size it reads a camera in, and the
ffmpeg command for the preview alone or with a recording."""

import importlib.machinery
import importlib.util
import pathlib
import subprocess

CAMERA = pathlib.Path(__file__).parents[2] / "desktop" / "capture" / "camera"

loader = importlib.machinery.SourceFileLoader("camera", str(CAMERA))
spec = importlib.util.spec_from_loader("camera", loader)
camera = importlib.util.module_from_spec(spec)
loader.exec_module(camera)

# As ffmpeg -f v4l2 -list_formats all lists a laptop's camera.
LAPTOP = """
[video4linux2,v4l2 @ 0x1] Compressed:       mjpeg :          Motion-JPEG : 1280x720 640x480 640x360 1920x1080 2560x1440
[video4linux2,v4l2 @ 0x1] Raw       :     yuyv422 :           YUYV 4:2:2 : 1280x720 640x480 640x360 320x240
"""
RAW_ONLY = """
[video4linux2,v4l2 @ 0x1] Raw       :     yuyv422 :           YUYV 4:2:2 : 1280x720 640x480 320x240
"""
METADATA = """
[video4linux2,v4l2 @ 0x1] ioctl(VIDIOC_G_FMT): Invalid argument
/dev/video1: Invalid argument
"""


def test_reads_formats_and_sizes():
    found = camera.formats(LAPTOP)
    assert found["mjpeg"][:2] == [(1280, 720), (640, 480)]
    assert (320, 240) in found["yuyv422"]


def test_motion_jpeg_at_its_largest_up_to_1080p():
    assert camera.choose(camera.formats(LAPTOP)) == ("mjpeg", (1920, 1080))


def test_uncompressed_only_up_to_480p():
    assert camera.choose(camera.formats(RAW_ONLY)) == ("yuyv422", (640, 480))


def test_a_device_without_formats_is_no_camera():
    assert camera.choose(camera.formats(METADATA)) is None


def test_preview_alone_reads_no_microphone_and_records_nothing():
    args = camera.command("/dev/video0", "mjpeg", (1280, 720), "/run/camera.jpg")
    assert args[args.index("-i") + 1] == "/dev/video0" and args.count("-i") == 1
    assert "libvpx-vp9" not in args
    assert args[-1] == "/run/camera.jpg" and "-atomic_writing" in args


def test_recording_with_the_microphone():
    args = camera.command("/dev/video0", "mjpeg", (1280, 720), "/run/camera.jpg", "/v/Video.webm", microphone=True)
    assert ["-f", "pulse"] == args[args.index("pulse") - 1: args.index("pulse") + 1]
    recording = args.index("/v/Video.webm")
    assert "libvpx-vp9" in args[:recording] and "libopus" in args[:recording]
    assert args[-1] == "/run/camera.jpg"


def test_recording_without_the_microphone_has_no_sound():
    args = camera.command("/dev/video0", "mjpeg", (1280, 720), "/run/camera.jpg", "/v/Video.webm")
    assert "pulse" not in args and "libopus" not in args


def test_bad_arguments_print_usage():
    for argv in ([], ["--record", "x"], ["p.jpg", "--record"], ["p.jpg", "--record", "x", "--loud"]):
        result = subprocess.run([CAMERA, *argv], capture_output=True, text=True, check=False)
        assert result.returncode == 2 and "Usage" in result.stderr
