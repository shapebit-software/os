# Desktop Environment

Wayland session boundaries, display and power behavior, media and notification policy, and indexes for the detailed ShapeBit Desktop interaction documents.

These pages are living architecture, not implementation evidence.

Concrete technology choices and lower-level implementation planning are kept
separately in [Desktop Technical Design](desktop-technical-design.md).

Changing a current rule requires updating its owning section and every affected
cross-area contract.

## On this page

- [Product design](#product-design)
- [Session and authority](#session-and-authority)
- [Displays and power](#displays-and-power)
- [Media and privacy](#media-and-privacy)

## Product design

### Vision and workspace model

- [Vision and goals](desktop-vision.md)
- [Workspaces](desktop-workspaces.md)
- [Window management](desktop-window-management.md)

### Shell surfaces

- [Radial context menus](desktop-radial-menus.md)
- [Notifications](desktop-notifications.md)
- [Background activity](desktop-background-activity.md)
- [Quick Settings](desktop-quick-settings.md)
- [Shelf](desktop-shelf.md)

### Input and local assistant

- [Gaze input](desktop-gaze-input.md)
- [Assistant framework](desktop-assistant-framework.md)
- [Assistant chat](desktop-assistant-chat.md)
- [Voice interaction](desktop-voice-interaction.md)

## Session and authority

### Desktop Session and Authorization Boundaries

#### Purpose and constraints

ShapeBit OS needs a custom Wayland desktop that can recover from ordinary UI
failures without turning display components into privileged policy engines. Its
per-user encrypted homes also require login, lock, local authorization, and
remote access to share one coherent session lifecycle.

#### Design

##### Desktop process model

Each graphical user session contains:

- one minimal compositor responsible for Wayland objects, outputs, input, and
  the authoritative locked/unlocked state;
- one restartable shell process containing the panel, launcher, notifications,
  and primary desktop UI;
- a separate trusted lock component;
- a separate trusted authorization agent.

A shell failure does not terminate applications or unlock the session. The
user service manager restarts the shell. The compositor retains the locked
state if the lock UI fails and restarts the lock component without exposing
the desktop.

The greeter runs in a separate system session with a separate compositor
process. It may reuse the same compositor implementation, but never the same
process or user authority as a logged-in desktop. Every graphical user session
receives its own compositor process.

ShapeBit initially permits only one logged-in graphical user session at a time.
Changing graphical user requires logout; fast user switching is deferred.
Non-graphical SSH sessions are not counted as graphical sessions.

##### Compositor failure

Wayland applications are not promised transparent reconnection after a
compositor failure. ShapeBit terminates the damaged graphical session, closes
its remaining processes, deactivates the home when no other session still uses
it, returns to the independent greeter, and records a diagnostic report.

Preserving unsaved work is an application-level recovery property. ShapeBit
system applications must provide continuous autosave and recovery where their
data model permits it. ShapeBit does not use process checkpointing and does not
guarantee recovery for third-party applications.

##### Privilege and account model

The compositor, shell, lock UI, authorization UI, and settings UI run without
root privileges. Narrow system services perform privileged work through
versioned D-Bus APIs. Polkit decides whether the active caller may authorize a
request. [Platform-Service API Contract](base-system.md) defines service names, caller-identity evidence,
authorization classes, versioning, errors, and job lifecycle.

The first human account created during installation is an administrator.
Additional accounts may be standard users or administrators. Administrator
applications still run unprivileged. A standard user's own password does not
authorize an administrator-only operation.

Direct login as `root` is disabled and the root account has no login password.
Administrative terminal work uses `sudo`; graphical work uses Polkit. Recovery
Kit credentials unlock encrypted data or recovery operations and do not grant
an administrator role.

The trusted authorization agent receives credentials directly for PAM/Polkit,
shows the exact requester and operation, and obtains compositor-controlled
exclusive input. A successful Polkit authentication is cached for a fixed five
minutes. Later requests do not extend that deadline. Every privileged request
during the cached period still receives a trusted **Yes**/**No** confirmation
that identifies the requester and operation. Lock, logout, or session
termination clears the cache immediately. Polkit and `sudo` caches are
independent.

The system-wide battery charge limit is a specific low-risk exception: only an
active local administrator may change it, but the trusted confirmation does not
request a password.

##### Developer mode and SSH

Developer mode is a per-user presentation and tooling setting. It may expose a
terminal, advanced application controls, and diagnostic logs, but does not
disable Secure Boot, update verification, or other system protections. Test
channels and local system-trust keys are separate administrator-authorized
system operations with explicit warnings.

The system SSH server is disabled by default and developer mode does not enable
it. Enabling or changing it is an administrator-authorized system operation.
Direct root login and password-only SSH login are disabled.

SSH public keys are stored in the `systemd-homed` user record so they can be
resolved while the encrypted home is inactive. Login behaves as follows:

- if the user's home is already active, the enrolled SSH key is sufficient;
- if the home is inactive, the key must succeed first and PAM then requests the
  user's normal password to unlock the home;
- a Recovery Kit credential is never accepted over SSH.

SSH sessions may coexist with the one graphical session. Local graphical logout
does not kill SSH sessions; the home remains active until the user's final
session ends. The logout UI reports active remote sessions and offers either
local graphical logout or termination of all sessions owned by that user.

#### Tradeoffs

- Routine shell and lock-UI failures have bounded effects.
- A compositor failure may lose unsaved third-party application state even
  though the system returns to a secure greeter.
- UI compromise does not itself grant root authority.
- Short-lived authorization caching improves usability while keeping every
  operation visible.
- Remote login to an inactive encrypted home requires both an SSH key and the
  home password.
- Active SSH work intentionally keeps that user's encrypted home unlocked.

#### Ownership boundaries

This section owns desktop process isolation, graphical session cardinality,
compositor-failure recovery, local authorization, administrator roles,
developer-mode security invariants, and SSH interaction with encrypted homes.
[Per-User Encrypted Homes](security-identity.md) remains authoritative for home encryption and PAM-based activation.
[Network Ownership and Privacy](security-identity.md) defines the network profiles on which SSH is exposed.

## Displays and power

### Display, Power, and Thermal Policy

#### Purpose and constraints

ShapeBit OS targets modern laptops without defining one reference model. Its
display and power design must cover mixed-density and mixed-capability monitors,
HDR, docking, encrypted-home suspension, battery behavior, and hardware thermal
limits without guessing model-specific firmware policy.

#### Design

##### Monitor layout and scaling

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

##### HDR, color, capture, and VRR

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

##### Suspend, lid, and hibernation

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

##### Power and thermal ownership

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

#### Tradeoffs

- Mixed-DPI, SDR/HDR, and variable-refresh setups are part of the initial test
  matrix rather than optional later enhancements.
- HDR materially increases compositor, driver, capture, and hardware validation
  work.
- Automatic docked mode is convenient but an external display disconnect with
  the lid closed intentionally suspends the machine.
- Initial systems cannot preserve RAM state across total power loss.
- Hardware-dependent settings appear only when a truthful capability probe
  succeeds.

#### Ownership boundaries

This section owns display layout defaults, scaling, HDR, VRR, lid behavior, power
profiles, initial sleep scope, and thermal policy. [Per-User Encrypted Homes](security-identity.md) owns home encryption
and the user-visible suspend-authentication setting. [Platform Scope and Hardware Validation](base-system.md) owns hardware
evidence labels and release gates.

## Media and privacy

### Media, Privacy, and Notification Policy

#### Purpose and constraints

Audio routing, microphone and camera access, screen sharing, remote input, and
notifications cross application, compositor, portal, and device boundaries.
ShapeBit needs predictable multimedia behavior and visible privacy controls
without claiming that an unsandboxed native executable is contained.

#### Design

##### Media architecture and audio policy

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

##### Microphone and camera

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

##### Screen capture and remote control

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
screen image and video capture are SDR as defined by [Display, Power, and Thermal Policy](desktop.md).

##### Notification policy

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

#### Tradeoffs

- Audio continues through ordinary shell restarts.
- Portal-controlled capture has an enforceable compositor boundary even for an
  unsandboxed AppImage.
- Microphone and camera privacy cannot be guaranteed against unsandboxed native
  code with direct device access.
- Remote control never implies authority over trusted authentication surfaces.
- Lock-screen and presentation notification policy favors privacy over immediate
  delivery.

#### Ownership boundaries

This section owns desktop media routing, capture consent, remote-input consent, and
notification privacy. [Application Platform and System Set](application-platform.md) owns AppImage isolation expectations. [Desktop Session and Authorization Boundaries](desktop.md)
owns trusted surfaces and session locking. [Display, Power, and Thermal Policy](desktop.md) owns HDR capture format.
