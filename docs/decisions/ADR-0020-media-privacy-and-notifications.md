# ADR-0020: Media, Privacy, and Notification Policy

**Status:** Accepted

**Date:** 2026-08-08

## Context

Audio routing, microphone and camera access, screen sharing, remote input, and
notifications cross application, compositor, portal, and device boundaries.
ShapeBit needs predictable multimedia behavior and visible privacy controls
without claiming that an unsandboxed native executable is contained.

## Decision

### Media architecture and audio policy

PipeWire is the common transport for audio, video capture, and screen-sharing
streams. WirePlumber is the per-user policy and session manager. Both run
independently of the shell; ShapeBit extends upstream policy narrowly rather
than creating a custom media server.

Connecting wired headphones automatically routes playback to them. A
user-initiated Bluetooth audio connection also becomes active. A new HDMI or
DisplayPort monitor does not steal audio unless the user selected that route
previously for the device. Disconnect returns streams to the best remaining
output.

Each output has a master volume. Active applications have independent volume
and mute controls remembered by application identity inside the encrypted
home. The normal UI stops at 100%; software amplification above 100% is
deferred. Applications cannot raise the session's master volume themselves.

### Microphone and camera

ShapeBit provides global microphone mute and camera-disable controls. Flatpak
access is granted per application through portals. While a controlled client
captures, the shell shows an unhideable system indicator naming the client.
Hardware mute, shutter, and camera-LED behavior takes precedence when exposed
by the device; ShapeBit does not override a hardware camera LED.

Locking the graphical session ends ordinary application access to microphone
and camera streams.

An unsandboxed AppImage may use PipeWire, in which case the normal indicator and
policy apply, but it may also attempt direct user-authorized device access.
ShapeBit therefore documents microphone and camera enforcement for AppImage as
best effort rather than a security guarantee.

### Screen capture and remote control

The compositor does not expose unrestricted screen-copy authority to ordinary
clients. Every new screen-share or recording session uses a portal to select a
window or monitor. Permission is not stored permanently. A persistent local
indicator names the session and provides immediate stop control.

Screen sharing stops at lock, and login, lock, and trusted authorization
surfaces are never included. This compositor boundary applies equally to
Flatpaks, system applications, and AppImage.

Remote keyboard and pointer control is a separate per-session request with a
separate trusted confirmation. The compositor marks synthetic input and rejects
it on the greeter, lock screen, and trusted authorization surface. Locking or
ending screen sharing revokes remote control.

Screen sharing sends image only by default. System-output audio and microphone
are independent, per-session choices. Initial system-audio capture contains the
whole active-output mix and warns that other applications and notification
sounds may be included; per-application audio capture is deferred. Initial
screen image and video capture are SDR as defined by ADR-0019.

### Notification policy

While a whole monitor is shared, ShapeBit automatically suppresses notification
banners and queues them in the notification center. The user may allow banners
for that sharing session. Sharing one window does not suppress unrelated local
banners. The previous notification mode returns when sharing ends. Critical
system UI may remain visible locally but is excluded from capture.

The lock screen shows no application notifications. It may show only
privacy-safe system messages needed to operate or protect the device, such as
critical battery, thermal shutdown, or a serious update failure. Application
notifications accumulated while locked produce one summary after unlock; their
individual banners are not replayed in a burst.

Only a ShapeBit-owned, root-running system service may send a critical
notification that bypasses **Do Not Disturb**. The broker verifies process
credentials and an allowlisted system interface; applications cannot obtain
critical status by declaring metadata. Calls, alarms, Flatpaks, and AppImage do
not bypass the policy automatically.

**Do Not Disturb** may be enabled manually or on a user schedule. Fullscreen
content alone does not enable it. Whole-monitor sharing uses the separate
automatic privacy behavior above.

## Consequences

- Audio continues through ordinary shell restarts.
- Portal-controlled capture has an enforceable compositor boundary even for an
  unsandboxed AppImage.
- Microphone and camera privacy cannot be guaranteed against unsandboxed native
  code with direct device access.
- Remote control never implies authority over trusted authentication surfaces.
- Lock-screen and presentation notification policy favors privacy over immediate
  delivery.

## Boundaries

This ADR owns desktop media routing, capture consent, remote-input consent, and
notification privacy. ADR-0023 owns AppImage isolation expectations. ADR-0018
owns trusted surfaces and session locking. ADR-0019 owns HDR capture format.

## Related decisions

- [ADR-0023](ADR-0023-application-platform-and-system-set.md)
- [ADR-0018](ADR-0018-desktop-session-and-authorization.md)
- [ADR-0019](ADR-0019-display-power-and-thermal-policy.md)

## References

- [PipeWire session manager responsibilities](https://docs.pipewire.org/page_session_manager.html)
- [WirePlumber session management](https://pipewire.pages.freedesktop.org/wireplumber/design/understanding_session_management.html)
- [Flatpak portals](https://docs.flatpak.org/en/latest/portals.html)
