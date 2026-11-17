# The assistant: answers and actions, on the computer or online. See ../package.macros.
%{load:%{packages}/package.macros}

Name:           shapebit-assistant
Version:        %{image_version}
Release:        %{shapebit_release}
Summary:        The assistant: answers and actions, on the computer or online
License:        %{shapebit_license}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make
# The assistant's language model server (llama-server@.service), built from
# llama.cpp (llama-server/ here, published in ShapeBit's repository); Fedora's
# llama-cpp is too old for Gemma 4. The model it serves is downloaded (extras).
Requires:       llama-server
# The assistant's soft sound when it takes a spoken request (the shell's
# services/Assistant.qml). Other packages bring it now; it is named so it stays.
Requires:       sound-theme-freedesktop
# The assistant's spoken answers (speak), with sherpa-onnx's Piper voices
# (dictation's python3-sherpa-onnx): sherpa-onnx 2 reads Piper voices only from
# phonemes, and nothing else in the image makes them.
Requires:       espeak-ng
Requires:       python3-sherpa-onnx

%description
The assistant answers and acts through typed actions, with a language model
on the computer (llama-server) or an online one; its model is an extra.

%install
%shapebit_install assistant

%files -f files
