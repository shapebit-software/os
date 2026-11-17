# Sound: PipeWire, and the bar's microphone level. See ../package.macros.
%{load:%{packages}/package.macros}

Name:           shapebit-sound
Version:        %{image_version}
Release:        %{shapebit_release}
Summary:        Sound: PipeWire, and the bar's microphone level
License:        %{shapebit_license}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make
# Sound (the shell's services/Audio.qml), for applications through PulseAudio and ALSA too.
Requires:       pipewire
Requires:       wireplumber
Requires:       pipewire-pulseaudio
Requires:       pipewire-alsa
Requires:       rtkit

%description
Sound for applications through PipeWire, PulseAudio, and ALSA, and the
microphone's level for the bar's microphone.

%install
%shapebit_install sound

%files -f files
