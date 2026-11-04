# Desktop Environment

ShapeBit's desktop runs on **Hyprland**, the compositor, and **Quickshell**,
the shell that draws the bars, panels, Settings, and the lock screen, in a
session run by **UWSM**. Its design follows the
[demo](https://shapebit.software/demo/); where this page and the demo
disagree, the demo decides. The source is in
[`desktop/`](https://github.com/shapebit-software/os/tree/main/desktop) of the
monorepo.

This page has two parts: the [desktop as built](#the-desktop-as-built), and
the [future design](#future-design) of what is not built yet.

## The desktop as built

### Session

- The login screen offers one session, ShapeBit. The login password unlocks
  the person's encrypted home and their keyring.
- The shell is the session's own service for what applications ask of the
  desktop: notifications, administrator passwords, network passwords and
  Bluetooth pairing, the file chooser, screen sharing, screenshots, and
  permission questions such as using the camera, or which app opens a file.
  Questions show centered over everything, with the screens dimmed, and wait
  their turn.
- Copied text stays available after the app it came from closes; only the
  last copy is kept, in memory, never on disk.
- Printing and email are not offered yet.

### Bars

- Two bars: the **system bar** (the clock and the status items) and the
  **dock** (Apps, the workspace maps, and the quick actions). Each can sit on
  any edge, and their items can move between the bars' zones or be hidden
  (Settings > Shell).
- The system bar's items each open a panel: **Notifications**,
  **Microphone** and **Sound**, **Brightness** (where the computer has a
  backlight), **Network** (Wi-Fi and Bluetooth, joined and paired in place),
  **Input language**, **Battery** with the power profile (where there is a
  battery), and the **System menu** (Settings, Lock, Suspend, Restart, Shut
  down, Log out). One panel is open at a time.

### Notifications

New notifications show as banners on the focused screen and stay in the
Notifications panel until dismissed. Critical ones stay until dismissed. **Do
Not Disturb** holds back all banners but critical ones, and keeps the
notifications all the same.

### Workspaces and Windows

- There is no Overview. The session starts with one workspace; dropping a
  window or an app on the "+" that the dock shows while dragging makes
  another, up to eight. A workspace without windows goes away.
- Each workspace has a **map** on the dock, showing its windows where they
  are. With the pointer, windows move only on the maps: drag a window onto
  another to swap them, or onto another map to move it there. There are no
  title bars to drag; the keyboard moves windows too.
- Windows tile in the workspace's layout: **Lead**, **Dwindle**,
  **Columns** (the default), **Center**, **Grid**, **Rows**, **Tabs**, and
  **Accordion**. Tabs and Accordion show one window at a time. Handles
  between tiles resize them.
- Apps show no close, minimize, or maximize buttons where they follow the
  system's setting; full screen covers the bars, with a button to end it.

### Keyboard

Every action has a shortcut, and **Super+/** shows them all on a picture of
the keyboard. The list is in [Shortcuts](Shortcuts.md).
Shortcuts work by the position of the key, whatever the layout; on the lock
screen only the sound, media, and brightness keys work.

### Apps and Quick Actions

- **Apps** lists the installed apps, with a search. A click opens an app on
  the current workspace; dragged onto a map, it opens there.
- The **quick actions** sit on a bar or open from a hot corner: the
  assistant, capturing, and dictation.
- **Capturing** opens one overlay for screenshots and recordings, of a
  selection, a window, or the screen. Screenshots are saved at once, or first
  open for markup; recordings can have a timer and the microphone. When an
  app shares the screen, the same overlay asks what to share, and the capture
  button shows while anything is shared.

### Dictation

Dictation starts from its quick action or Super+D and writes into the app the
person is in; it is separate from the assistant. Speech recognition runs on
the computer: live, while the person speaks, in 25 languages once its
[extra](#extras) is downloaded; otherwise in 100 languages once the person
stops. The language follows the keyboard layout (Settings > Language).

- Text goes straight into the text field only if the same field still has
  the focus when the text is ready, and goes in as text, not keys, so it
  can't trigger shortcuts. Otherwise it waits in a card, to insert, copy,
  type, add to, or discard.
- Password fields never get dictated text.
- An open microphone is always visible on the bar. Audio stays on the
  computer and goes when the dictation ends. Locking the screen discards
  everything under way.

### Lock, Idle, and Sleep

The lock screen looks like the login screen. The screen locks after the idle
time chosen in Settings > Account and before the computer sleeps; the screens
turn off after their own idle time.

### Settings

Settings is part of the shell and has only what works: **Account**,
**Assistant**, **Language**, **Time**, **Desktop**, **Shell**, **Windows**,
**Display**, **Mouse**, **Network**, **Sound**, **Apps**
([Applications](Design-Applications.md#installing-apps)),
**Downloads**, and **Updates**, with a search across them. Settings for the
whole computer, such as the system language and the time zone, ask for an
administrator's password.

Not built yet: the first day of the week, dragging tabs, and keeping tile
sizes across sessions.

### Updates

The system updates itself in the background
([Lifecycle](Design-Lifecycle.md#system-updates)). Once an update is
ready, a notification says so, once, and **Restart** in the system menu reads
**Restart to update**. Apps update daily; a running app gets its update the
next time it opens.

### Downloads

Everything the desktop downloads and installs goes through one queue: the
browser and apps from Welcome, installs and removals in Settings > Apps,
extras, and the daily app updates. One job runs at a time, outside the shell,
so it goes on if the shell restarts, and what a logout stopped starts again at
the next sign-in. **Settings > Downloads** shows the queue, where each job can
be cancelled or tried again; a download goes on where it stopped.

### Extras

Extras are what is too large for the system image and not everyone needs,
such as speech and language models. They are downloaded once for everyone on
the computer, checked against known hashes, and only administrators may add
or remove them. They are kept apart from the sealed system, so the system
needs none of them and updates without them. Welcome offers them; Settings >
Assistant adds and removes them later.

### Assistant

The assistant answers questions and acts on the computer when asked. As in
the demo, it has three levels:

- The **command line**, from its button, the hot corner, or Super+A, for a
  quick question.
- The **sidebar**, which holds one conversation beside the windows.
- **Conversations**, the list of all of them, with a search.

The assistant acts only through typed actions, never a command it writes.
Each action shows as a card, and has a risk:

- **Read** (the computer's status, the installed apps, finding files by name)
  runs at once.
- **Change** (volume, brightness, keyboard layout, Do Not Disturb, Wi-Fi,
  Bluetooth, opening apps, moving windows, screenshots, locking) asks on its
  card: once, always for that group, or not at all. Settings > Assistant shows
  the groups, to allow or take back. A change can be undone from its card.
- **Confirm** (shutting down, restarting, installing or removing an app) asks
  every time.

One assistant serves the whole session, with one queue of requests, and runs
outside the shell. Locking the screen hides it, and nothing new starts until
unlock. Conversations and an activity log stay on the computer, the log for
as long as Settings > Assistant chooses.

A model on the computer and an online one work the same way. The built-in
model, Gemma 4 E2B, is an [extra](#extras): on by default in Welcome where
the computer has memory enough, and it runs only while in use. A person can
add their own models, online ones too, with their keys in the keyring.

### Welcome

Each person's first login opens Welcome. It asks only what the installer
didn't:

1. **Network**, only if the computer was offline when Welcome opened.
2. **Browser**, only when online
   ([Internet Browsers](Design-Applications.md#internet-browsers)).
3. **Recommended apps**, only when online
   ([Recommended Apps](Design-Applications.md#recommended-apps)).
4. **Optional downloads** ([Extras](#extras)), only when online, for
   administrators.
5. **Installing**, which queues what was chosen and shows how it goes.
6. **Getting around**: the main ways to move around the desktop.

**Skip all** ends Welcome on any step, and what is installing goes on.
Settings > Account opens Welcome again. If Welcome closed while the computer
was offline, a notification offers to finish setting up once it is online.

## Future design

Nothing in this part is built yet, except dictation and the
[assistant](#assistant)'s chat, actions, and models. The assistant's chat
follows the demo, which replaced the chat designed here.

### Radial Context Menus

The shell's and ShapeBit's own apps' context menus are radial ("pie")
menus. Third-party apps keep their own menus.

- They open on the secondary button, or the Menu key or a long press, around
  the pointer or the focused object. A press, a move into a wedge, and a
  release runs that action; releasing in the center keeps the menu open.
- A ring holds at most eight wedges, each in a fixed direction for its kind
  of object; menus never reorder. The primary action is at the top, and
  destructive ones in a consistent lower sector, marked by icon and color.
  Unavailable actions stay, disabled. At most two secondary levels.
- Near a screen edge the whole ring shifts inward; the pointer never jumps.
- Destructive, privileged, or consent-requiring actions still go through
  their usual confirmation. The menu checks its target again before it acts.
- The keyboard works throughout, nothing depends on color, motion, or speed
  alone, and the menu never times out.

### Shelf

The Shelf is a temporary place to keep things at hand while working across
workspaces: global to the person, and cleared at logout.

- Things enter only by an explicit action, such as a drag or **Send to
  Shelf**; the clipboard is never captured. Files and folders stay
  references; text, images, and links become the Shelf's own copies.
- It opens from a screen edge (the bottom by default), first as a compact
  preview, then as the full Shelf, over the windows without changing their
  layout, and from a shortcut, above full screen too.
- Items keep their order, can be dragged in and out, and opening one leaves
  it there. Removing one, or clearing the Shelf, is immediate, with Undo.
- Copies share a size limit; nothing is evicted silently.

### Assistant Framework

The assistant framework is the shared foundation for assistant and agent
interaction.

- Voice and chat are two ways into the same assistant, with the same access
  and confirmations, and one queue of requests in arrival order. Stopping a
  request lets the next one start; it never rolls back what is done.
- The assistant may read the person's files, window contents, and clipboard.
  Changes are off until allowed per group, and destructive, privileged, or
  outward actions always ask. Permissions are per agent and per capability,
  in one place that shows and takes them back. Approvals are given on the
  card, with the pointer or keyboard, not by voice.
- Memory stays on the computer and can be viewed, edited, and cleared; raw
  audio and transcripts never persist.
- Open: how window contents differ from screen pixels, which each need a
  fresh grant under the media and privacy policy; detailed capability scopes;
  and isolating future agents.

### Voice Interaction

Talking to the assistant, as dictation already does for text:

- Only push-to-talk or a click; never always listening. Speech and requests
  stay on the computer, and audio and transcripts are discarded after each
  interaction. Never on the login screen, the lock screen, or password
  prompts.
- No modes: the **sparkle** button, held, sends speech to the assistant; the
  **waveform** button dictates into the app.
- Answers are spoken by default, on the computer, ducking other sound. A
  click on the indicator or a new push-to-talk stops speech. A request that
  needs a permission shows the same card as chat.

### Gaze Input

An optional way to move the pointer to where the person looks:

- Looking alone never moves or clicks anything: a key or button moves the
  pointer to the latest stable gaze point, without snapping to controls.
- Camera frames and gaze data stay on the computer and in memory; no app or
  agent can read them. A privacy indicator shows while tracking, and
  tracking stops on the login and lock screens.
- It needs calibration per display, and pauses when calibration is
  unreliable. Without supported hardware, Settings shows it as unavailable.
