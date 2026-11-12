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
  **dock** (Apps, the workspace maps, and the quick actions: **Capture**,
  **Dictation**, and the **Assistant**). Each can sit on any edge and has
  three zones. In Settings > Shell, items are dragged to a place in any
  zone, or selected to move one place at a time, to be hidden, or, on the
  dock, to be full or half size; two half-size buttons share a slot.
- The system bar's items each open a panel: **Notifications**, which also
  shows what is downloading, **Microphone** and **Sound**, **Brightness** (where the computer has a
  backlight), **Network** (Wi-Fi and Bluetooth, joined and paired in place),
  **Input language**, **Battery** with the power profile (where there is a
  battery), and the **System menu** (Settings, Lock, Suspend, Restart, Shut
  down, Log out). One panel is open at a time.
- **Background apps**: applications that keep running without a window show
  their icons in the middle of the system bar, side by side or, as set in
  Settings > Shell, stacked until the pointer is on them. A click does what
  the application does for it; a right click opens its menu. The item shows
  only while there are such applications.

### Notifications

The **Notifications** panel, opened from the bell or with Super+N, is the
notification center: messages and downloads wait there. The bell is next to
the clock by default, and shows only while there is a notification or a
download, or Do Not Disturb is on; Settings > Notifications can show it
always.

- **Banners:** a new notification shows as a banner on the focused screen,
  nearest the bell, so in the corner by the clock by default, for a few
  seconds, or longer under the pointer.
  Low-urgency ones show no banner; critical ones stay until dismissed. At most
  three banners show, and the rest are counted in "+N more", which opens the
  panel. A banner and its card show up to three of the notification's actions
  as buttons; a click elsewhere on it opens what it is about.
- **History:** notifications stay in the panel until dismissed, grouped by
  app, the group with the newest first. A group shows its newest notification
  and unfolds the rest; a group can be cleared, and all at once. Where the app
  takes a reply, the card has a field for it. History survives a reload of the
  shell, not the end of the session, and is never written to disk.
- **Downloads:** while anything downloads or installs, the bell has a badge
  with an arrow down, and the panel shows each job first, with its progress; a click
  opens [Settings > Downloads](#downloads). One that fails says so in a
  notification.
- **Do Not Disturb** holds back all banners but critical ones, and keeps the
  notifications all the same. A right click on the bell turns it on and off,
  as does Settings > Notifications, which also chooses how long it stays on:
  for 1 hour, until tomorrow (7:00), or until turned off. Banners are held back in
  the same way while the screen is shared. When either ends, one banner says
  how many came meanwhile.
- **Per app:** Settings > Notifications lists each app that has sent a
  notification, with a choice: **Banners**, **Center only**, or **Off**, which
  drops its notifications. The app's page in Settings > Apps has the same
  choice.
- **Lock screen:** shows only how many notifications wait.

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
the computer, live while the person speaks, in any of 25 languages. Its model
is an [extra](#extras): the image ships no speech model, so dictation works
once the extra is downloaded, and until then its button leads to the download.

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
**Downloads**, **Updates**, and **Licenses**, with a search across them. Settings for the
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
the next sign-in. The [Notifications](#notifications) panel shows what is
under way. **Settings > Downloads** shows the queue, where each job can
be cancelled or tried again; a download goes on where it stopped.

### Licenses

**Settings > Licenses** names the license of ShapeBit OS, opens the license
texts of Fedora and the other programs in `/usr/share/licenses`, and lists
each work that an extra holds: who made it, its license, any changes, and a
link to its source, also before it is downloaded. Each downloaded extra also
keeps the same in its `NOTICE` file.

### Extras

Extras are what is too large for the system image and not everyone needs,
such as speech and language models. They are downloaded once for everyone on
the computer, checked against known hashes, and only administrators may add
or remove them. They are kept apart from the sealed system, so the system
needs none of them and updates without them. Welcome offers them; Settings >
Assistant adds and removes them later.

### Assistant

The assistant answers questions and acts on the computer when asked. It runs
on the computer: its model is local, and nothing asked leaves the computer.
Online models are planned as a choice a person makes; the model catalog
already allows for them.

One conversation shows in one of three ways, and moving between them loses
nothing:

- **Bubbles**, by the assistant's button: each message is a card of its own.
  The latest three show in full and the older ones are dimmed, until the
  person scrolls back through them. Below them is the reply line. A bubble,
  or the reply line, opens the conversation in the panel.
- The **panel**, at the right of the screen over the windows. Pushing the
  pointer against the middle of the screen's right edge opens it too. Its
  header starts a new conversation, lists all of them with a search, shows
  the conversation as bubbles again, docks the panel, and hides it.
- The panel **docked**: it looks like a tile and reserves its width, so the
  windows retile beside it, but it is outside the tiling and stays on every
  workspace. Its left edge resizes it. A screen narrower than 1024 pixels has
  no room for it, and keeps the panel over the windows.

A tap on Super, or a click on the assistant's button, opens what was open
last, and closes it again. A docked panel stays: the tap gives it the
keyboard, and the next one gives the keyboard back to the window.

**Voice**: hold Super, or the assistant's button, speak, and let go. What was
said is the request. Nothing opens while the person speaks: the button shows
sound bars while the assistant listens, and its sparkle turns while the
assistant works. The answer comes up as a bubble and goes again after a few
seconds, unless it waits for the person. Bubbles come up the same way for
any answer that arrives while the assistant is hidden.

- Super counts as held after 0.4 seconds alone. Any other key in that time
  makes it a shortcut, and a key pressed while the assistant listens discards
  what was said.
- The microphone opens only while the key or button is held, for a minute at
  most, and never on the lock screen or at a password prompt. The recording goes when the request
  is made; the words stay, as the request in the conversation.
- Speech is written down by the dictation model, so voice needs that
  [extra](#extras) too. [Dictation](#dictation) is separate: its words go
  into the app, never to the assistant.
- The model starts loading when the person starts to speak.

The assistant sees only what a request tells it: the selected text and the
focused window's app and title. The reply line shows both before sending,
each to take off, and the request's bubble says what went along. It does not
see the clipboard, the screen, or other windows' contents.

A conversation left for half an hour is over: the next request from the
bubbles or by voice begins a new one. The panel goes on in the conversation
it shows.

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

Approvals are given on the card, with the pointer or keyboard, never by
voice. Typed and spoken requests share one queue, in the order they came;
stopping one lets the next start, and never rolls back what is done.

One assistant serves the whole session and runs outside the shell. Locking
the screen hides it, and nothing new starts until unlock. Conversations and
an activity log stay on the computer: conversations until deleted, the log
for as long as Settings > Assistant chooses.

The model, Gemma 4 E2B, is an [extra](#extras): on by default in Welcome
where the computer has memory enough, and it runs only while in use.

The assistant always says that an AI answers, as the EU's AI Act asks
(article 50): "AI · on this computer" under the reply line, and that answers
can be wrong at the start of a conversation.

Not built yet: spoken answers, memory across conversations, reading a
window's contents, and online models.

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

Nothing in this part is built yet.

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

### Gaze Input

An optional way to move the pointer to where the person looks:

- Looking alone never moves or clicks anything: a key or button moves the
  pointer to the latest stable gaze point, without snapping to controls.
- Camera frames and gaze data stay on the computer and in memory; no app or
  agent can read them. A privacy indicator shows while tracking, and
  tracking stops on the login and lock screens.
- It needs calibration per display, and pauses when calibration is
  unreliable. Without supported hardware, Settings shows it as unavailable.
