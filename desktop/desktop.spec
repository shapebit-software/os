# The desktop: compositor configuration, shell, session, helpers, and the
# license texts of the models that are extras. Built in every image build from
# the same commit (image/Containerfile), never published: its version is the
# image's, and its sources are this repository. Its Requires are what it runs
# on, each with the reason for it: Hyprland, its dialogs, hypridle,
# xdg-desktop-portal-hyprland, and Quickshell come from a third-party COPR
# (image/hyprland.repo), python3-sherpa-onnx and llama-server from ShapeBit's own
# repository (third-party/README.md), and the rest from Fedora. Build it with
#   rpmbuild -bb --define "image_version VERSION" --define "source_dir DESKTOP" desktop.spec

Name:           desktop
Version:        %{image_version}
Release:        1
Summary:        ShapeBit's desktop
License:        LicenseRef-PolyForm-Shield-1.0.0
URL:            https://github.com/shapebit-software/os
# Marks ShapeBit's own packages, whose sources are this repository (scripts/release/sources.py).
Vendor:         ShapeBit
BuildArch:      noarch
BuildRequires:  make

# The compositor, the shell's runtime, and the session.
Requires:       hyprland
# Hyprland's own dialogs, such as when an application stops responding; it warns
# on the screen without them.
Requires:       hyprland-guiutils
Requires:       quickshell
Requires:       uwsm
# Idle time, the lock screen, and sleep (shell/services/Idle.qml).
Requires:       hypridle
# Screen sharing and global shortcuts (portal/portals.conf).
Requires:       xdg-desktop-portal-hyprland
# Screenshots and recordings (shell/services/Capture.qml), to the person's Pictures and Videos.
Requires:       grim
Requires:       slurp
Requires:       wf-recorder
Requires:       xdg-user-dirs
# Voice and camera recordings (shell/services/Capture.qml, capture/camera) and
# Skip silence (capture/skip-silence), on the ffmpeg libraries that wf-recorder
# already brings; Opus and VP9, as no H.264 is shipped.
Requires:       ffmpeg-free
# The phonemes of the assistant's spoken answers (dictation/speak): sherpa-onnx 2
# reads Piper voices only from phonemes, and nothing else in the image makes them.
Requires:       espeak-ng
# ONNX Runtime for Smart Turn, which hears when the person is done speaking in
# voice mode (dictation/dictate-engine); sherpa-onnx links the same library
# but has no Python interface to it.
Requires:       python3-onnxruntime
# The sound theme: the assistant's soft sound when it takes a spoken request
# (shell/services/Assistant.qml). Other packages bring it now; it is named so it stays.
Requires:       sound-theme-freedesktop
# The clipboard, kept after the application it came from closes (shell/services/Clipboard.qml).
Requires:       clipman
Requires:       wl-clipboard
# The display's brightness and the power profile.
Requires:       brightnessctl
Requires:       power-profiles-daemon
# Battery state (shell/services/Battery.qml).
Requires:       upower
# Sound (shell/services/Audio.qml), for applications through PulseAudio and ALSA too.
Requires:       pipewire
Requires:       wireplumber
Requires:       pipewire-pulseaudio
Requires:       pipewire-alsa
Requires:       rtkit
# Dictation (dictation/dictate): pw-record hears the microphone. The text goes
# in as the input method, which needs no package; wtype types it only when the
# person asks, for applications that do not say if they have a text field.
# sherpa-onnx, which writes speech down, is not Fedora's: ShapeBit builds it
# against Fedora's ONNX Runtime (third-party/sherpa-onnx), and Parakeet, which it
# runs, is downloaded (extras/extra). dictate-engine uses Fedora's NumPy.
Requires:       pipewire-utils
Requires:       wtype
Requires:       python3-sherpa-onnx
Requires:       python3-numpy
# The assistant's language model server (assistant/llama-server@.service), built
# from llama.cpp (third-party/llama-server); Fedora's llama-cpp is too old for
# Gemma 4. The model it serves is downloaded (extras/extra).
Requires:       llama-server
# Secrets (the Secret Service and its portal), unlocked by the login password:
# SDDM's PAM configuration calls pam_oo7 when it is installed.
Requires:       oo7-daemon
Requires:       oo7-portal
Requires:       pam_oo7
# The shell's portal, connection agent, app installer, and share picker (portal/, session/, apps/).
Requires:       python3-gobject
# The shell's monospace font.
Requires:       jetbrains-mono-fonts

%description
ShapeBit's desktop: Hyprland's configuration, the Quickshell shell with its
settings, the assistant, dictation, capture, downloads and the app center, their
helpers and user units, and the license texts of the models it downloads.

%install
make -C %{source_dir} install DESTDIR=%{buildroot}
# Every file it installs is the package's: desktop/Makefile is the one list.
(cd %{buildroot} && find . ! -type d | sed 's|^\.||') > files

%files -f files
%dir %{_datadir}/desktop
%dir %{_libexecdir}/desktop
