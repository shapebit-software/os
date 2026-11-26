# sherpa-onnx's Python package, built from source against Fedora's onnxruntime,
# for dictation (packages/dictation). Upstream downloads its dependencies while it
# builds; they are Sources here, at the versions and hashes that its
# cmake/*.cmake pin (the build checks them), so the build runs offline and the
# source RPM holds all the code. Built and published by packages/repositories/tools/rpm-build.sh
# (packages/repositories/README.md).

%global ver 2.0.1
# setup.py installs with make install/strip, so there is no debug information.
%global debug_package %{nil}

# Named as its folder and spec are (packages/repositories/README.md); the
# Python package is python3-sherpa-onnx.
Name:           sherpa-onnx
Version:        %{ver}
Release:        1%{?dist}
Summary:        Speech recognition, synthesis and voice activity detection with ONNX Runtime
# sherpa-onnx, kaldi-native-fbank, kaldi-decoder, kaldifst, simple-sentencepiece, openfst: Apache-2.0
# kissfft: BSD-3-Clause; hclust-cpp: BSD-2-Clause; utf8proc: MIT AND Unicode-DFS-2015
# nlohmann/json: MIT; pybind11: BSD-3-Clause; Eigen: MPL-2.0
License:        Apache-2.0 AND BSD-3-Clause AND BSD-2-Clause AND MIT AND Unicode-DFS-2015 AND MPL-2.0
URL:            https://github.com/k2-fsa/sherpa-onnx
Source0:        %{url}/archive/refs/tags/v%{ver}.tar.gz#/sherpa-onnx-%{ver}.tar.gz
Source1:        https://github.com/csukuangfj/kaldi-native-fbank/archive/refs/tags/v1.22.4.tar.gz#/kaldi-native-fbank-1.22.4.tar.gz
Source2:        https://github.com/JuliaStrings/utf8proc/archive/refs/tags/v2.12.0.tar.gz#/utf8proc-2.12.0.tar.gz
Source3:        https://github.com/k2-fsa/kaldi-decoder/archive/refs/tags/v0.3.0.tar.gz#/kaldi-decoder-0.3.0.tar.gz
Source4:        https://github.com/pkufool/simple-sentencepiece/archive/refs/tags/v0.7.tar.gz#/simple-sentencepiece-0.7.tar.gz
Source5:        https://github.com/nlohmann/json/archive/refs/tags/v3.12.0.tar.gz#/json-3.12.0.tar.gz
Source6:        https://github.com/csukuangfj/hclust-cpp/archive/refs/tags/2026-02-25.tar.gz#/hclust-cpp-2026-02-25.tar.gz
Source7:        https://github.com/pybind/pybind11/archive/refs/tags/v3.0.0.tar.gz#/pybind11-3.0.0.tar.gz
Source8:        https://gitlab.com/libeigen/eigen/-/archive/5.0.1/eigen-5.0.1.tar.gz
Source9:        https://github.com/csukuangfj/openfst/archive/refs/tags/v1.8.5-2026-07-09.tar.gz#/openfst-1.8.5-2026-07-09.tar.gz
# kaldi-native-fbank's own dependency, from its cmake/kissfft.cmake
Source10:       https://github.com/mborgerding/kissfft/archive/febd4caeed32e33ad8b2e0bb5ea77542c40f18ec.zip#/kissfft-febd4caeed32e33ad8b2e0bb5ea77542c40f18ec.zip
# kaldi-decoder's own dependency, from its cmake/kaldifst.cmake
Source11:       https://github.com/k2-fsa/kaldifst/archive/refs/tags/v1.8.0.tar.gz#/kaldifst-1.8.0.tar.gz

BuildRequires:  cmake
BuildRequires:  gcc-c++
BuildRequires:  onnxruntime-devel
BuildRequires:  python3-devel
BuildRequires:  python3-setuptools
BuildRequires:  python3-wheel
BuildRequires:  unzip

%global _description %{expand:
sherpa-onnx runs speech recognition, speech synthesis, voice activity detection
and related models locally with ONNX Runtime.}

%description %_description

%package -n python3-sherpa-onnx
Summary:        %{summary}
# What it bundles, so that the SBOM lists it (distribution/sbom/sbom.py).
Provides:       bundled(kaldi-native-fbank) = 1.22.4
Provides:       bundled(kissfft) = 0^20250528gitfebd4ca
Provides:       bundled(utf8proc) = 2.12.0
Provides:       bundled(kaldi-decoder) = 0.3.0
Provides:       bundled(simple-sentencepiece) = 0.7
Provides:       bundled(json) = 3.12.0
Provides:       bundled(hclust-cpp) = 2026.02.25
Provides:       bundled(pybind11) = 3.0.0
Provides:       bundled(eigen3) = 5.0.1
Provides:       bundled(openfst) = 1.8.5
Provides:       bundled(kaldifst) = 1.8.0

%description -n python3-sherpa-onnx %_description

%prep
%autosetup -n sherpa-onnx-%{ver} -p1
# cmake/*.cmake take a dependency from the source directory when it is there.
cp -p %{SOURCE1} %{SOURCE2} %{SOURCE3} %{SOURCE4} %{SOURCE5} %{SOURCE6} %{SOURCE7} %{SOURCE8} %{SOURCE9} %{SOURCE10} %{SOURCE11} .
# Each bundled library's license texts, for %%license.
extract() {
  local archive=$1 name=$2 top
  top=$(basename "$archive" .tar.gz)
  shift 2
  mkdir -p "licenses/$name"
  tar -xzf "$archive" -C "licenses/$name" --strip-components=1 "${@/#/$top/}"
}
extract %{SOURCE1} kaldi-native-fbank LICENSE
extract %{SOURCE2} utf8proc LICENSE.md
extract %{SOURCE3} kaldi-decoder LICENSE
extract %{SOURCE4} simple-sentencepiece LICENSE
extract %{SOURCE5} json LICENSE.MIT
extract %{SOURCE6} hclust-cpp LICENSE
extract %{SOURCE7} pybind11 LICENSE
extract %{SOURCE8} eigen COPYING.README COPYING.MPL2 COPYING.APACHE COPYING.BSD COPYING.MINPACK
extract %{SOURCE9} openfst COPYING
extract %{SOURCE11} kaldifst LICENSE
unzip -q %{SOURCE10} '*/COPYING' '*/LICENSES/BSD-3-Clause' -d licenses
mv licenses/kissfft-* licenses/kissfft
# Link Fedora's onnxruntime where it is installed; do not copy it into the
# package (modified from upstream: this rule removed).
grep -q 'install(FILES ${onnxruntime_lib_files} DESTINATION lib)' cmake/onnxruntime.cmake
sed -i '/install(FILES ${onnxruntime_lib_files} DESTINATION lib)/d' cmake/onnxruntime.cmake

%generate_buildrequires
%pyproject_buildrequires

%build
export SHERPA_ONNXRUNTIME_INCLUDE_DIR=%{_includedir}/onnxruntime
export SHERPA_ONNXRUNTIME_LIB_DIR=%{_libdir}
export SHERPA_ONNX_MAKE_ARGS="%{?_smp_mflags}"
# The library and its bindings only: no demo programs, microphone or server.
export SHERPA_ONNX_CMAKE_ARGS="-DCMAKE_BUILD_TYPE=RelWithDebInfo -DSHERPA_ONNX_ENABLE_BINARY=OFF -DSHERPA_ONNX_ENABLE_PORTAUDIO=OFF -DSHERPA_ONNX_ENABLE_WEBSOCKET=OFF -DSHERPA_ONNX_ENABLE_TESTS=OFF"
%pyproject_wheel

%install
%pyproject_install
# The library only; its command line tool needs click, which nothing here uses.
rm %{buildroot}%{_bindir}/sherpa-onnx-cli
# Its C and C++ interface (libraries, headers, pkg-config file), which the
# Python module neither links nor loads.
rm -r %{buildroot}%{python3_sitearch}/sherpa_onnx/include
rm %{buildroot}%{python3_sitearch}/sherpa_onnx/sherpa-onnx.pc \
   %{buildroot}%{python3_sitearch}/sherpa_onnx/lib/libsherpa-onnx-c-api.so \
   %{buildroot}%{python3_sitearch}/sherpa_onnx/lib/libsherpa-onnx-cxx-api.so
%pyproject_save_files -l sherpa_onnx
# The list comes from the wheel's record, which still names them.
sed -i -e '\|/sherpa_onnx/include|d' -e '\|/sherpa_onnx/sherpa-onnx\.pc|d' \
  -e '\|/sherpa_onnx/lib/libsherpa-onnx-c\(xx\)\?-api\.so|d' %{pyproject_files}

%check
%py3_check_import sherpa_onnx

%files -n python3-sherpa-onnx -f %{pyproject_files}
%license licenses/*

%changelog
* Mon Nov 16 2026 ShapeBit <noreply@shapebit.software> - 2.0.1-1
- First build
