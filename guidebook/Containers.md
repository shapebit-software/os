# Containers

The system itself is read-only, so you install command-line tools and
development environments in containers. ShapeBit comes with
[Distrobox](https://distrobox.it) and rootless Podman:

```sh
distrobox create --name work
distrobox enter work
```

A new container starts from the Fedora version that ShapeBit is based on.
Inside it, install anything with `sudo dnf install`. The Terminal opens on the
system and in your containers.

Distrobox is for convenience, not a security sandbox: a container can read
and change your home.

A ShapeBit image for development is planned.
