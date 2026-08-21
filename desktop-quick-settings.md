# Quick Settings

**Status:** Draft

Quick Settings provides fast access to selected system controls without
replacing the complete Settings application. This document records intended
behavior, not implemented or verified desktop behavior.

## Panel placement

- Quick Settings is one global panel. Clicking a system-bar status cluster
  opens the panel on that cluster's display; the keyboard shortcut uses the
  focused window's display. Only one instance is visible at a time.
- Clicking outside, pressing Escape, or clicking the originating status cluster
  again closes the panel without changing settings by itself. Applied changes
  remain in effect; unsaved form edits are discarded.

## Interaction model

- The panel always opens as one overview rather than jumping to a section based
  on the status icon used to open it.
- The overview visibly groups controls in the fixed order **Connectivity**,
  **Privacy**, **Sound & Display**, and **Power**. Each group has a small visible
  text heading in addition to spacing and visual separation. User reordering is
  deferred to a future version and will be configured through the full Settings
  application. The initial panel has no search, pinning, custom tiles, or local
  reordering.
- The panel is bounded by the available display height. When its groups do not
  fit, they scroll inside the panel while the Settings button remains fixed and
  visible.
- Controls always reflect actual system state and update live when hardware,
  another application, or another session changes that state.
- Tab and Shift+Tab move between controls. Arrow keys operate sliders and
  choices within the focused control; Enter or Space activates it.
- Keyboard focus remains inside the open panel. Closing it returns focus to the
  system-bar control or window that opened it. Every icon, state, progress
  indicator, and error has an accessible text label; important distinctions do
  not depend on color alone. The panel respects text scaling, high contrast,
  reduced motion, and screen-reader output.
- Switches, sliders, and device choices apply immediately. A view containing
  editable values uses an explicit **Save**, **Start**, or equivalent action;
  closing the view or panel discards its unsaved edits. Leaving a detail view or
  closing the panel hides revealed secrets and QR codes, which must be revealed
  explicitly again.
- If a setting change fails, its control returns to the actual system state and
  shows an inline explanation without closing the panel. The error remains
  until a later attempt succeeds or the panel closes; it has no separate
  dismiss control.
- While a setting change is in progress, its control shows a progress state and
  prevents repeated activation until the operation completes. Closing the panel
  does not cancel the operation; reopening it shows the operation's current or
  final actual state. If it fails while the panel is closed, ShapeBit delivers
  a normal failure [notification](desktop-notifications.md). Successful
  completion while the panel is closed remains silent and is reflected only in
  the resulting system status.
- Binary settings use switch tiles. The initial examples include Wi-Fi and
  Bluetooth. Airplane Mode is also an initial switch tile on devices with
  supported wireless hardware. Airplane Mode controls wireless radios rather
  than all networking: it disables Wi-Fi and Bluetooth and stops an active
  hotspot, while Ethernet remains usable. VPN follows the remaining transport
  and its normal reconnect and kill-switch rules. Turning Airplane Mode off
  restores each radio to its individual state from before it was enabled but
  does not restart the hotspot. Individual radios cannot be re-enabled while
  Airplane Mode remains active.
- When wired networking is present, **Connectivity** shows a read-only Ethernet
  status row with connection state and the network name when known. Detailed
  wired configuration remains in the full Settings application.
- The Wi-Fi detail view lists visible networks and supports connecting or
  disconnecting without leaving Quick Settings. A simple network password is
  entered inside the same detail view. Certificate-based or otherwise advanced
  setup closes the panel and opens the relevant page in the full Settings
  application. The connected network appears first, followed by saved networks
  and then other available networks ordered by signal strength. Each row shows
  connection state, signal strength, and whether the network is secured, but
  does not claim an estimated internet speed. Quick Settings does not provide a
  **Forget** action; saved-network management remains in the full Settings
  application.
- The Bluetooth detail view shows connected devices first, then paired devices,
  then newly discovered devices. Pairing and connect or disconnect actions stay
  inside the panel. PIN or passkey entry and comparison also remain in the
  detail view. A pairing failure shows an inline error and leaves the panel
  open. New-device discovery runs while the detail view is open; connected and
  paired devices remain visible without continuous aggressive scanning. A
  device battery level appears only when the device reports it reliably. Quick
  Settings does not provide an unpair action; removing a paired device remains
  in the full Settings application.
- A Mobile Hotspot tile appears only when the Wi-Fi hardware supports hotspot
  mode. On first use, it opens a detail view with a neutral generated network
  name and a secure random password; broadcasting begins only after the user
  activates **Start**. The detail view continues to show and allow editing of
  the saved hotspot name and password after initial setup. The password is
  masked by default and has explicit reveal and **Copy** controls; copying does
  not reveal it onscreen. The detail view also provides a QR code that another
  device can scan to join, but the code remains hidden until the user activates
  **Show QR code**. Saving a changed name or password while the hotspot is active
  requires confirmation that connected devices will be disconnected. After
  confirmation, the hotspot restarts automatically with the new credentials.
  Later uses may toggle the saved hotspot directly. While it is active, the
  detail view lists the devices currently connected to it and provides a
  **Disconnect** action for each device. Each device shows its reported name
  when available, otherwise its IP and MAC addresses. Disconnecting is temporary
  and does not prevent that device from reconnecting with the password; device
  blocking is available only in the full Settings application. An active
  hotspot's overview tile shows its number of connected devices. The hotspot
  continues while the session is locked but stops automatically at logout or
  restart.
- A VPN tile appears only after at least one VPN is configured. Its switch
  connects or disconnects the most recently selected VPN; its detail view
  selects another configured VPN. When connected, the overview tile shows the
  active profile's name. If that profile has its kill switch enabled, the tile
  also shows a read-only **Kill switch** badge; changing that profile option
  remains in the full Settings application. If its tunnel becomes unavailable
  while the kill switch blocks traffic, the tile prominently shows
  **Reconnecting — network blocked**. A reconnecting profile without a kill
  switch instead shows **Reconnecting — traffic not protected**. The compact
  system-bar VPN indicator also visually distinguishes connected,
  reconnecting-with-traffic-blocked, and reconnecting-without-protection states;
  hovering it shows the active profile name and exact connection and protection
  state. The initial release allows only one active VPN profile at a time;
  selecting another disconnects the current VPN before connecting the new one.
  If the new connection fails, ShapeBit automatically attempts to reconnect the
  previously active VPN. If restoration also fails, the error reports both
  failures and states explicitly that no VPN is active.
  Switching otherwise starts immediately without an additional confirmation;
  the confirmation and authorization requirements in
  [ADR-0021](adr-0021-network-ownership-and-privacy.md) still apply. Supported
  VPN types and system-wide routing remain governed by
  [ADR-0025](adr-0025-enterprise-network-authentication.md) and the
  [system design](system-overview.md).
- Cellular, NFC, and other additional radio controls are deferred until their
  hardware and policy models are designed. Quick Settings does not claim a
  dedicated captive-portal workflow; that remains outside the initial release
  under ADR-0021.
- A Camera switch tile exposes the global camera-disable control defined by
  [ADR-0020](adr-0020-media-privacy-and-notifications.md) and applies to all
  applications subject to that decision's documented enforcement boundaries.
  Its direct meaning is **On = camera available** and **Off = camera globally
  blocked**. If a controlled client retains an active camera session while
  access is disabled, the unhideable privacy indicator remains visible, names
  the client, and shows that the camera is blocked.
- Hardware microphone-mute and camera-shutter states take precedence over the
  software controls. When hardware blocks access, the corresponding software
  control is unavailable and labeled **Blocked by hardware**. Per-application
  microphone and camera permission management remains in the full Settings
  application.
- **Privacy activity** lists ongoing microphone, camera, screen-sharing, and
  remote-control activity. Entries are ordered by sensitivity: remote control,
  screen sharing, camera, then microphone, with the newest activity first within
  each type. Each entry shows the application, the accessed resource or shared
  scope, and how long the activity has been active. An entry exposes **Stop**
  whenever the controlled capture or remote-control boundary supports immediate
  revocation, consistent with ADR-0020. Stop acts immediately without
  confirmation, revokes only the selected activity, and does not change the
  global Camera or microphone-mute controls. Stopping remote control leaves its
  associated screen-sharing session active. Stopping screen sharing also
  revokes any remote-control session attached to it.
  Attached remote-control and screen-sharing activity remains in separate
  entries, but the panel visually links those entries. When no Privacy activity
  is ongoing, its list is hidden while the normal Privacy controls remain
  visible. Ended activity disappears from Quick Settings immediately; the panel
  does not include recent history, and the desktop does not retain a Privacy
  activity history elsewhere. Unhideable privacy indicators remain visible
  above Quick Settings itself and are never suppressed by opening the panel.
- Continuous settings such as output volume and display brightness use sliders.
  The overview volume slider names and controls the current default audio
  output. Hardware volume keys and external state changes update it live. Its
  detail view selects another output device and lists active applications with
  current audio streams, each with independent volume and mute controls. An
  application leaves the list when its streams end, while its settings remain
  remembered for the next stream. Clicking the speaker icon toggles mute;
  unmuting restores the previous volume. Normal volume is limited to 100%; the
  panel does not offer software amplification.
  The overview also exposes microphone input volume and input-device selection
  rather than placing them only in the audio detail view. Clicking the
  microphone icon toggles input mute; unmuting restores the previous input
  level. Its direct meaning is **On = input available** and **Muted = input
  globally blocked**. This is the global microphone mute defined by
  [ADR-0020](adr-0020-media-privacy-and-notifications.md): it affects
  applications and local-assistant voice input, subject to that decision's
  documented enforcement boundaries. If a controlled client retains an active
  microphone session while global mute blocks input, the unhideable privacy
  indicator remains visible, names the client, and shows that input is muted.
  The overview brightness slider controls the display containing the panel. Its
  detail view provides separate controls for other displays whose brightness
  can be controlled reliably. Layout, scale, orientation, primary-display
  choice, and color calibration remain in the full Settings application.
- A Night Light switch tile appears in **Sound & Display**. Its detail view
  controls color temperature and scheduling. Night Light is disabled by
  default. First activation turns it on immediately without creating a
  schedule; scheduling remains optional. When a schedule exists, a manual
  switch change overrides it only until the next scheduled transition.
- An HDR switch tile appears only when the display containing the panel supports
  HDR and controls that display only. Its detail view provides separate controls
  for other supported displays. While HDR is active, the detail view provides
  separate sliders for physical display brightness and the reference brightness
  of SDR content. HDR state and safe SDR fallback remain defined by
  [ADR-0019](adr-0019-display-power-and-thermal-policy.md).
- A VRR control appears only when the display containing the panel supports
  variable refresh rate. It shows **Automatic for fullscreen** by default and
  allows VRR to be disabled for that display, consistent with ADR-0019.
- If the current display pipeline cannot safely combine HDR, VRR, Night Light,
  or another selected mode, Quick Settings preserves the working configuration,
  disables the conflicting control, and explains why rather than silently
  degrading display state. Keyboard-backlight and automatic-brightness controls
  are deferred until ShapeBit defines their hardware-policy model.
- When a setting has additional choices, its tile label or a separate details
  affordance opens a focused detail view inside the same panel without changing
  the setting. A Back control returns to the overview. The switch itself changes
  the setting immediately. Returning from the detail view restores keyboard
  focus to the control that opened it.
- In a detail view, Escape returns to the overview. Pressing Escape again closes
  the panel.
- A persistent **Settings** button closes Quick Settings and opens the full
  Settings application. If a Settings window already exists, ShapeBit switches
  to its Workspace and focuses it without moving it. Otherwise, Settings opens
  in the active Workspace on the display where the panel was shown.
- A control for hardware the device does not support is hidden. A supported
  control that is temporarily unavailable remains visible but disabled and
  explains the blocking condition.
- On battery-powered devices, the overview shows battery percentage, charging
  state, and a remaining-time estimate only when the system considers that
  estimate reliable for the main system battery. Peripheral batteries remain
  with their owning device controls, such as a headset battery under Bluetooth,
  and are not combined with the system estimate. The overview also shows a
  power-profile selector. The available profiles are **Balanced**, **Power
  Saver**, and **Performance** when the platform supports it, as defined by
  [ADR-0019](adr-0019-display-power-and-thermal-policy.md). When low battery
  automatically activates Power Saver, the selector labels it **Power Saver —
  Automatic** and temporarily disables the other profiles. Connecting external
  power restores the previously selected profile. When thermal policy limits
  performance, the panel shows **Performance limited by temperature**; thermal
  protection remains informational and cannot be disabled. Battery conservation
  and charging-limit controls remain in the full Settings application because
  they are system-wide and may require administrator confirmation under
  ADR-0019.
- Power actions are presented as commands rather than switches. The Power
  control opens a focused view inside the panel and never performs a command
  immediately. Its initial commands are **Lock**, **Suspend**, **Log Out**,
  **Restart**, and **Shut Down**. Lock and Suspend act immediately. Log Out,
  Restart, and Shut Down require explicit confirmation. The confirmation names
  known blocking applications and, when the command affects them, other active
  local and SSH sessions. It also warns that ShapeBit cannot reliably detect or
  preserve every piece of unsaved work. **Cancel** receives initial focus in
  these destructive confirmations. When an update is staged, the relevant
  command may be labeled **Restart and Update**, while confirmation, recovery,
  and failure behavior remain governed by
  [ADR-0027](adr-0027-staged-restart-ux.md).

## System-bar status cluster

- The compact status cluster prioritizes exceptional states such as offline
  connectivity, a reconnecting VPN without protection, network traffic blocked
  by a kill switch, global microphone mute, global camera blocking, and low
  battery rather than permanently displaying every enabled feature.
- Hover text provides the exact state and relevant device or profile name.
  Critical distinctions use different icons or badges as well as color.

## Initial scope exclusions

- **Do Not Disturb** remains exclusively in the
  [Notification panel](desktop-notifications.md) and is not duplicated in Quick
  Settings.
- Accessibility shortcuts, appearance and theme selection, keyboard layout,
  location services, and similar controls remain in the full Settings
  application initially. If later promoted, they use the planned configurable
  tile system rather than expanding the fixed initial panel.
