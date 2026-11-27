"""Capture in the container image: what its recordings need."""

import pytest

pytestmark = pytest.mark.system_image


def test_capture_has_its_encoders_and_devices(sh):
    # Voice and camera recordings, and Skip silence, need Opus and VP9 from
    # Fedora's ffmpeg, which has no H.264 (src/camera).
    encoders = sh("ffmpeg -hide_banner -encoders")
    assert "libopus" in encoders and "libvpx-vp9" in encoders
    assert "pulse" in sh("ffmpeg -hide_banner -devices") and "v4l2" in sh("ffmpeg -hide_banner -devices")
