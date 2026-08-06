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

## Login surface

The future ShapeBit login screen is a replaceable frontend over the system
authentication stack. It uses PAM to authenticate the user; `pam_systemd_home`
then unlocks and mounts that user's LUKS2 home before the session starts.

The login screen must:

- request the user's password once;
- avoid implementing password verification or storage cryptography;
- remain functional without access to any user's home;
- start a session only after PAM and home activation succeed;
- clear credentials from memory promptly and never log them;
- expose recovery as an explicit, distinguishable flow;
- provide equivalent behavior to the prototype TTY login.

The session lock screen is a separate state from initial login. Suspend-time
home locking may be enabled only after the external lock screen can reliably
reauthenticate and reactivate the home.

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
