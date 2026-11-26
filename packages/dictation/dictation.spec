# Dictation: speech written into the application in use. See ../package.macros.
%{load:%{packages}/package.macros}

Name:           shapebit-dictation
Version:        %{image_version}
Release:        %{shapebit_release}
Summary:        Dictation: speech written into the application in use
License:        %{shapebit_program} AND %{shapebit_config}
URL:            %{shapebit_url}
Vendor:         %{shapebit_vendor}
BuildArch:      noarch
BuildRequires:  make
# pw-record hears the microphone. The text goes in as the input method, which
# needs no package; wtype types it only when the person asks, for applications
# that do not say if they have a text field.
Requires:       pipewire-utils
Requires:       wtype
# sherpa-onnx, which writes speech down, is not Fedora's: ShapeBit builds it
# against Fedora's ONNX Runtime (sherpa-onnx/), and Parakeet, which it runs, is
# downloaded (extras). dictate-engine uses Fedora's NumPy.
Requires:       python3-sherpa-onnx
Requires:       python3-numpy
# ONNX Runtime for Smart Turn, which hears when the person is done speaking in
# voice mode (dictate-engine); sherpa-onnx links the same library but has no
# Python interface to it.
Requires:       python3-onnxruntime

%description
Dictation writes speech into the application in use, with Parakeet on the
computer through sherpa-onnx (sherpa-onnx/ here, published in ShapeBit's
repository).

%install
%shapebit_install dictation

%files -f files
