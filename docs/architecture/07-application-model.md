# 07. Application Model

**Status:** Draft

## Software categories

| Type | Mechanism |
|---|---|
| desktop application | Flatpak |
| web application | browser/PWA |
| development tool | Toolbox/Podman |
| host service | system image |
| driver/kernel module | image or controlled extension |
| mandatory component | system image |

## Store

The target store should hide:

- Flatpak runtimes;
- repositories;
- dependencies;
- package names;
- technical sandbox details.

It should instead show:

- application source;
- verification level;
- required permissions;
- size;
- update history.

## Repositories

Planned levels:

- Verified;
- Community;
- Developer.

## Host extensions

The first release may not support public host extensions. Later options include:

- image variants;
- systemd-sysext;
- signed extension packages;
- a catalog of official add-ons.

Arbitrary `sudo dnf install` operations on the host are not a supported workflow.
