# 02. System Architecture

**Status:** Draft

## Layers

```text
User applications
        ↓
Flatpak + portals
        ↓
ShapeBit Desktop
        ↓
Wayland compositor
        ↓
D-Bus platform services
        ↓
systemd / logind / NetworkManager / PipeWire
        ↓
ShapeBit OS image
        ↓
bootc
        ↓
Fedora / kernel / Mesa / hardware
```

## Responsibility boundaries

### Fedora

Provides the base packages, kernel, Mesa, systemd, and RPM infrastructure.

### bootc

Handles OCI image transport, deployment preparation, version switching, and rollback.

### ShapeBit OS image

Defines the exact host contents, configuration, security policies, and desktop components.

### Flatpak

Provides user applications and their sandbox.

### Development containers

Provide compilers, SDKs, and tools without polluting the host.

## Main custom components

- `shapebit-compositor`
- `shapebit-shell`
- `shapebit-settings`
- `shapebit-updater`
- `shapebit-onboarding`
- `shapebit-recovery`
- `shapebit-support-report`
- `shapebit-platform-services`

## Modularity principle

A launcher, panel, or settings failure should not terminate the entire session. Components should be independent processes managed by systemd user services.
