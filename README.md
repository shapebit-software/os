# ShapeBit OS

ShapeBit OS is an image-based Linux desktop operating system built on Fedora.

## Setup

```bash
git clone --recurse-submodules https://github.com/shapebit-software/os.git
```

## Development

The desktop and installer share one Fedora development container, configured
in the root `distrobox.ini`. Run these commands from the monorepo root:

```sh
DBX_CONTAINER_MANAGER=docker distrobox assemble create --file distrobox.ini
DBX_CONTAINER_MANAGER=docker distrobox enter shapebit-dev
```

Inside the container, change into `desktop/` or `installer/` and follow that
project's development instructions. Both use the same installed tools and
libraries. Use the same container manager for creation and entry; replace
`docker` with `podman` if that is your host's engine.

Image builds and VM tests still use the host's container engine and QEMU;
see [image requirements](image/README.md#requirements). The website keeps its
Ruby environment managed by [mise](website/README.md#local-development).

## Documentation

- [Architecture](https://github.com/shapebit-software/docs/wiki/Architecture)

## Project links

- [ShapeBit website](https://shapebit.software)
- [GitHub organization](https://github.com/shapebit-software)
- [Issue tracker](https://github.com/shapebit-software/os/issues)
