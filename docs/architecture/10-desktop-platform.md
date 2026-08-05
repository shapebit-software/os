# 10. Desktop Platform

**Status:** Draft

## Components

- Wayland compositor;
- shell;
- launcher;
- panel;
- notifications;
- quick settings;
- lock screen;
- settings;
- portals;
- Polkit agent;
- D-Bus services.

## Proposed stack

- Rust;
- Smithay;
- systemd user services;
- D-Bus;
- PipeWire;
- xdg-desktop-portal;
- libinput;
- Mesa/DRM/KMS.

## Minimal compositor

The first version provides:

- `xdg-shell`;
- one output;
- keyboard and mouse input;
- focus;
- window movement, maximization, and closing;
- a nested backend;
- basic logging;
- application launching;
- optional XWayland later.

## Platform API

Planned areas:

- appearance;
- display;
- power;
- applications;
- permissions;
- updates;
- notifications;
- search;
- accounts;
- devices.

The API should be versioned and separate the UI from its implementation.
