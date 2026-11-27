# What every feature with Rust programs (a Cargo.toml) shares. Its Makefile
# includes this after package.mk; its install target needs `build crates`
# and installs the programs from $(release).
#
# Cargo builds offline with Fedora's crates, which the spec's BuildRequires
# install, from a copy in CARGO_TARGET_DIR: it writes Cargo.lock beside
# Cargo.toml, and the image build's source tree is read-only. The copy keeps
# the files' times, so nothing unchanged is rebuilt. Its home is there too:
# the image build's /root is a link to nowhere.
#
# The crates the programs are built from are in the package: their list,
# cargo-vendor.txt, from which rpm's cargo generator gives the package's
# Provides: bundled(crate(...)) for the SBOM; and their license texts, which
# their licenses require to ship with the programs (crates.py). `make
# licenses` prints their licenses, for the spec's License.

feature  := $(notdir $(CURDIR))
CARGO_TARGET_DIR ?= $(or $(TMPDIR),/tmp)/cargo/$(feature)
release  := $(CARGO_TARGET_DIR)/release
copy     := $(CARGO_TARGET_DIR)/source
registry := /usr/share/cargo/registry
cargo    := cd $(copy) && CARGO_HOME=$(CARGO_TARGET_DIR)/home cargo --offline --config 'source.crates-io.replace-with="fedora"' \
  --config 'source.fedora.directory="$(registry)"'
# The crates: those the programs use, with what those use, on this computer's
# architecture; not those that only build or test them.
tree     := $(cargo) tree --edges normal --prefix none --format '{p}|{l}'
crates   := $(CURDIR)/../crates.py

.PHONY: copy build test licenses crates

copy:
	rm -rf $(copy) && mkdir -p $(copy) && cp -rp Cargo.toml src $(copy)/

build: copy ## Build the Rust programs
	$(cargo) build --release --target-dir $(CARGO_TARGET_DIR)

test: copy ## Run the Rust programs' unit tests
	$(cargo) test --target-dir $(CARGO_TARGET_DIR)

licenses: copy ## Print the licenses of the crates in the programs, for the spec's License
	$(tree) | python3 $(crates) licenses

crates: copy
	$(tree) | python3 $(crates) install $(registry) $(share)/licenses/shapebit-$(feature)
