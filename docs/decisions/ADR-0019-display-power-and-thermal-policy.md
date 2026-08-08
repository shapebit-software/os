# ADR-0019: Display, Power, and Thermal Policy

**Status:** Accepted

**Date:** 2026-08-08

## Context

ShapeBit OS targets modern laptops without defining one reference model. Its
display and power design must cover mixed-density and mixed-capability monitors,
HDR, docking, encrypted-home suspension, battery behavior, and hardware thermal
limits without guessing model-specific firmware policy.

## Decision

### Monitor layout and scaling

With the laptop lid open, a newly connected monitor extends the desktop and the
built-in panel remains primary. With the lid closed, an active external monitor
automatically activates docked mode: the built-in panel turns off and an
external monitor becomes primary. AC power is not required. Disconnecting the
last external monitor while the lid remains closed immediately requests
suspend.

Display layout, orientation, scale, and primary-output choice are stored per
user and per detected monitor set. The greeter uses an independent safe
automatic layout because a user's configuration is inside the encrypted home.

Per-output integer and fractional scaling is required in the initial release.
The UI includes common values such as 100%, 125%, 150%, 175%, and 200%, while
allowing the compositor to recommend a value from display characteristics.
Wayland clients that do not render at the preferred fractional scale may be
compositor-scaled with reduced sharpness.

### HDR, color, capture, and VRR

HDR and color management are initial-release requirements. HDR is enabled
manually and remembered per monitor. A failed HDR modeset returns safely to SDR.

The compositor maintains a high-precision color representation and processes
each output independently. A client-declared HDR surface remains HDR on a
capable enabled output and is tone-mapped on an SDR output. Undeclared content
is treated as SDR/sRGB. A window spanning outputs is transformed separately for
each output portion. Enabling HDR on one output does not change another output.

HDR mode exposes separate controls for physical display brightness and the
reference brightness of SDR content. Screenshots, recordings, and screen-share
streams are tone-mapped to SDR in the initial release; native HDR capture is
deferred.

Variable refresh rate is an initial-release feature on capable outputs. It is
enabled automatically for a fullscreen application, can be disabled per
monitor, and falls back to fixed refresh if the combined monitor, driver, HDR,
or VRR configuration fails.

### Suspend, lid, and hibernation

Suspend-to-RAM is the initial sleep mechanism. When **Require authentication
after suspend** is enabled, the session locks and `systemd-homed` removes active
home keys from memory. Processes and SSH sessions remain present but home I/O
waits until one resume authentication restores home access and the session.

When the user disables that setting, ShapeBit also leaves the home key active;
the UI warns that resume is unlocked and suspend no longer provides the same
physical-access protection.

Closing the lid requests suspend unless docked mode is active. If suspend fails
while the lid remains closed, ShapeBit performs a controlled shutdown rather
than leave an active laptop in an enclosed space.

Hibernation, hybrid sleep, and suspend-then-hibernate are outside the initial
release. ShapeBit does not recommend disabling Secure Boot to obtain them. A
future design must authenticate and encrypt the resume image and pass a broad
hardware test matrix. At critical battery, the initial system warns and then
performs a controlled shutdown, relying on application autosave for recovery.

### Power and thermal ownership

A system-level ShapeBit power-policy service observes power supply, lid,
battery, and kernel/firmware thermal state. It applies policy and requests
suspend or controlled shutdown independently of the shell and logged-in user.
The shell is an unprivileged presentation and settings client.

The initial profiles are **Balanced**, **Power Saver**, and, only when the
platform exposes it, **Performance**. Balanced is the default. Low battery
temporarily activates Power Saver and connection to external power restores the
previous profile.

ShapeBit does not directly control fans or define one temperature threshold for
all laptops. Firmware and kernel drivers own fan control and hardware limits.
The power service reacts to their warning and critical states, reduces power at
warning level, reports the event, and performs controlled shutdown at critical
level. Applications and users cannot disable critical thermal protection.

Battery charging defaults to 100%. When a standard kernel/firmware mechanism is
available, an administrator may enable a system-wide conservation limit such as
80%. Unsupported hardware does not show a non-functional setting. The trusted
UI requires **Yes**/**No** confirmation from an active local administrator but
does not require a password for this low-risk setting.

## Consequences

- Mixed-DPI, SDR/HDR, and variable-refresh setups are part of the initial test
  matrix rather than optional later enhancements.
- HDR materially increases compositor, driver, capture, and hardware validation
  work.
- Automatic docked mode is convenient but an external display disconnect with
  the lid closed intentionally suspends the machine.
- Initial systems cannot preserve RAM state across total power loss.
- Hardware-dependent settings appear only when a truthful capability probe
  succeeds.

## Boundaries

This ADR owns display layout defaults, scaling, HDR, VRR, lid behavior, power
profiles, initial sleep scope, and thermal policy. ADR-0011 owns home encryption
and the user-visible suspend-authentication setting. ADR-0014 owns hardware
evidence labels and release gates.

## Related decisions

- [ADR-0011](ADR-0011-per-user-encrypted-homes.md)
- [ADR-0014](ADR-0014-platform-and-hardware-validation.md)
- [ADR-0018](ADR-0018-desktop-session-and-authorization.md)

## References

- [Wayland color management protocol](https://wayland.app/protocols/color-management-v1)
- [Linux DRM color pipeline](https://docs.kernel.org/gpu/rfc/color_pipeline.html)
- [Linux suspend-to-disk documentation](https://docs.kernel.org/power/swsusp.html)
