# The assistant: answers and actions, on the computer or online. See packaging's package.macros.
%{load:%{shapebit_macros}}

Name:           shapebit-assistant
Version:        %{shapebit_version}
Release:        %{shapebit_release}
Summary:        The assistant: answers and actions, on the computer or online
License:        %{shapebit_program} AND %{shapebit_config}
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

%description
The assistant answers and acts through typed actions, with a language model
on the computer (llama-server) or an online one; its model is an extra.

%install
%shapebit_install assistant

%files -f files
