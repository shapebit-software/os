# 08. Development Workflow

**Status:** Draft

## Types of work

### Applications

Code in `/home`, toolchains in Toolbox, local execution, and Flatpak distribution.

### Compositor and shell

Fast tests in nested mode; session tests in a VM; production delivery as RPMs in the image.

### System services

Compilation in an SDK container, RPM packaging, a local bootc image, and testing in QEMU.

### Boot or kernel changes

Only through a developer image and VM or dedicated test hardware.

## Three development loops

### Fast

```text
edit → build → run nested/locally
```

### Integration

```text
edit → RPM → bootc image → QEMU
```

### Release

```text
merge → CI → signed RPMs → image → tests → channel
```

## Developer image

It should contain:

- debug symbols;
- SSH;
- GDB/LLDB;
- sanitizers;
- extended logging;
- systemd and SELinux analysis tools;
- an easy way to switch to a local build.

## Rule

The official stable image is never modified manually. Experiments take place in a container, temporary overlay, VM, or the developer channel.
