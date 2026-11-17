# llama.cpp's llama-server, the assistant's language model server
# (desktop/assistant/llama-server@.service); Fedora's llama-cpp is too old for
# Gemma 4. It and its libraries stay in /usr/libexec/llama, apart from
# Fedora's, with one build of the CPU code per kind of processor, chosen as it
# runs. No web page and no downloads: the model is an extra. Its vendored code
# is in its source tree, so the build runs offline. Built and published by
# scripts/rpm-build.sh (third-party/README.md).

%global ver 0.8.0
# Its libraries are private to it: not offered to other packages, and not
# required from them.
%global __provides_exclude_from ^%{_libexecdir}/llama/.*$
%global __requires_exclude ^lib(ggml|ggml-base|llama|llama-common|llama-server-impl|mtmd)\\.so

Name:           llama-server
Version:        %{ver}
Release:        1%{?dist}
Summary:        Language model server of llama.cpp
# llama.cpp, ggml, llamafile, cpp-httplib, nlohmann/json, rotate-bits: MIT
# xxhash: BSD-2-Clause; sha1, sha256: public domain; subprocess.h: Unlicense
# stb_image: MIT OR Unlicense; miniaudio: MIT-0 OR Unlicense
License:        MIT AND BSD-2-Clause AND LicenseRef-Fedora-Public-Domain AND Unlicense AND (MIT OR Unlicense) AND (MIT-0 OR Unlicense)
URL:            https://github.com/ggml-org/llama.cpp
Source0:        %{url}/archive/refs/tags/v%{ver}.tar.gz#/llama.cpp-%{ver}.tar.gz

BuildRequires:  cmake
BuildRequires:  gcc-c++
Provides:       bundled(ggml) = %{ver}
Provides:       bundled(llamafile)
Provides:       bundled(cpp-httplib) = 0.62.0
Provides:       bundled(json) = 3.12.0
Provides:       bundled(xxhash) = 0.8.3
Provides:       bundled(sha1)
Provides:       bundled(sha256)
Provides:       bundled(rotate-bits)
Provides:       bundled(subprocess-h)
Provides:       bundled(stb_image) = 2.30
Provides:       bundled(miniaudio) = 0.11.25

%description
llama-server serves language models in the GGUF format over HTTP, from
llama.cpp. ShapeBit's assistant starts it for the model the person downloaded.

%prep
%autosetup -n llama.cpp-%{ver} -p1
# Each vendored library's license text, for %%license, and llamafile's notice,
# which is at the start of its source file.
mkdir notices
cp -p LICENSE licenses/LICENSE-* notices/
cp -p vendor/cpp-httplib/LICENSE notices/LICENSE-cpp-httplib
for text in vendor/hash/*/LICENSE*; do
  cp -p "$text" "notices/LICENSE-$(basename "$(dirname "$text")")"
done
sed -n '/^\/\//!q;p' ggml/src/ggml-cpu/llamafile/sgemm.cpp >notices/LICENSE-llamafile
grep -q 'Permission is hereby granted' notices/LICENSE-llamafile

%build
%set_build_flags
# Shared libraries beside the program, found through $ORIGIN; every CPU
# variant as a backend loaded at run time; no tests, examples, web page or TLS.
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON \
  -DCMAKE_INSTALL_RPATH='$ORIGIN' -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
  -DGGML_NATIVE=OFF -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON -DGGML_BACKEND_DIR=%{_libexecdir}/llama \
  -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_UI=OFF \
  -DLLAMA_USE_PREBUILT_UI=OFF -DLLAMA_OPENSSL=OFF
cmake --build build %{?_smp_mflags} --target llama-server

%install
install -d %{buildroot}%{_libexecdir}/llama
cp -a build/bin/llama-server build/bin/*.so* %{buildroot}%{_libexecdir}/llama/

%check
build/bin/llama-server --version

%files
%license notices/*
%{_libexecdir}/llama/

%changelog
* Tue Nov 17 2026 ShapeBit <noreply@shapebit.software> - 0.8.0-1
- First build
