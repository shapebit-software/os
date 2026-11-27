# Capture: screenshots, screen and voice recordings, and the camera. See packaging's package.macros.
%{load:%{shapebit_macros}}

Name:           shapebit-capture
Version:        %{shapebit_version}
Release:        %{shapebit_release}
Summary:        Capture: screenshots, screen and voice recordings, and the camera
License:        %{shapebit_program}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make
# Screenshots and recordings (the shell's services/Capture.qml), to the
# person's Pictures and Videos.
Requires:       grim
Requires:       slurp
Requires:       wf-recorder
Requires:       xdg-user-dirs
# Voice and camera recordings (camera) and Skip silence (skip-silence), on the
# ffmpeg libraries that wf-recorder already brings; Opus and VP9, as no H.264 is
# shipped.
Requires:       ffmpeg-free

%description
Screenshots and recordings of the screen, the voice, and the camera, with
Skip silence; the shell's capture overlay drives them.

%install
%shapebit_install capture

%files -f files
