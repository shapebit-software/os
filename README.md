# ShapeBit OS

ShapeBit OS is an image-based Linux desktop operating system built on Fedora
bootc. This repository coordinates the product architecture and the first
implementation repositories.

## Repository layout

```text
os/
├── docs/        # architecture, decisions, roadmaps, and checklists
├── image/       # bootc image Git submodule
└── installer/   # installer Git submodule
```

The implementation directories are independent Git repositories. Clone them
with the coordination repository:

```bash
git clone --recurse-submodules https://github.com/shapebit-software/os.git
```

For an existing clone:

```bash
git submodule update --init --recursive
```

The configured submodule URLs use SSH and therefore require GitHub SSH access.

## Start here

1. Read the [documentation index](docs/README.md).
2. Check the [current project status](docs/roadmap/PROJECT-STATUS.md).
3. Follow the [first-prototype plan](docs/architecture/14-first-prototype.md).
4. Use the component instructions in the
   [image](https://github.com/shapebit-software/image) and
   [installer](https://github.com/shapebit-software/installer) repositories.

Architecture proposals describe intended behavior, not completed features.
Accepted architecture decisions are recorded in `docs/decisions/`.

## Project links

- [ShapeBit website](https://shapebit.software)
- [GitHub organization](https://github.com/shapebit-software)
- [Issue tracker](https://github.com/shapebit-software/os/issues)
