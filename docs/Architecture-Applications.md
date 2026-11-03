# Applications

The OS combines a small set of built-in apps with a wide selection of
third-party software and support for portable AppImage apps.

## Built-in Apps

These apps ship as part of the OS image itself. Every user gets the same
versions, and they update and roll back together with the OS:

- **Settings**
- **Files** (Nautilus, Fedora's RPM: GNOME publishes no Flatpak of it)
- **Diagnostics**

Each one has a defined scope, so it is clear which app owns a given task:

- **Files** handles archives and thumbnails.
- **Diagnostics** owns process and resource monitoring.
- **Settings** owns disk, storage, firmware, device, and printing
  configuration.
- The shell (not an app) owns screenshots and screen recording.

Settings is part of the shell, and installing and removing apps is its **Apps**
section ([below](#installing-apps)). Diagnostics is not built yet.

## Recommended Apps

On first login, Welcome ([Desktop](Architecture-Desktop.md#welcome)) installs
these apps from Flathub into the person's own Flatpak installation. All are
on; each can be turned off so it isn't installed:

- **Terminal** (Ptyxis)
- **Text Editor** (GNOME Text Editor)
- **Image Viewer** (Loupe)
- **Document Viewer** (Papers)
- **Video Player** (Showtime)
- **Audio Player** (Decibels)
- **Calculator** (GNOME Calculator)

They open their file types by default; where two of them open the same
type, the image sets which one does. Office suites, scanning apps, editors
for media, and browsers are installed separately.

## Installing Apps

The image ships Flatpak, with Flathub as its system-wide remote, which
Flatpak adds by itself on first use.

**Settings > Apps** ([Desktop](Architecture-Desktop.md#settings)) is a store that
opens on all apps, verified ones first, with a search and categories, and can
show only the installed. It installs and removes them in the person's own
Flatpak installation, through the desktop's one queue of downloads, which
Settings > Downloads shows with each install's progress
([Desktop](Architecture-Desktop.md#downloads)). It is drawn by the shell;
separate helper programs do the work, so a failure there can't take the shell
down. Searches
run on Flathub's catalogue as Flatpak downloads it, on the computer, so what
someone looks for isn't sent anywhere; an app's screenshots come from Flathub
when its details open.

Apps is to show exactly two sources; today it shows Flathub:

- **Flathub**, for third-party applications.
- The **OS repository**, for apps and integration packages that
  OS itself builds and maintains. It is to be built with AetherPak
  ([Distribution](Architecture-Lifecycle.md#distribution)); it doesn't exist
  yet.

The OS repository may contain own binaries, but it never
stores, mirrors, or redistributes a third party's binaries — those always
come from Flathub or the vendor directly.

Adding other Flatpak remotes is possible, but it is an advanced, per-user
option that most users won't need.

Removing an app asks first and keeps its data unless told to delete it, and
then removes the runtimes nothing uses anymore. Built-in apps can't be removed.

### Internet Browsers

On first login, Welcome
([Desktop](Architecture-Desktop.md#welcome)) lets an online user pick a default
browser from:

1. Google Chrome
2. Chromium
3. Firefox
4. GNOME Web

Nothing is preselected, and none has to be; offline, the step is left out.
The chosen browser installs into that user's Flatpak installation and becomes
their default.

How each browser is packaged:

- **Chrome** — Flathub's package, which downloads Google's official
  package from Google when it installs and checks it against the checksum
  that the package pins. Flathub, not Google, maintains it.
- **Chromium** — Fedora's official Flatpak, from Fedora's registry
  (registry.fedoraproject.org), built by Fedora from its own packages.
- **Firefox** and **GNOME Web** — installed from their regular Flathub
  packages.

Chromium adds Fedora's registry to that user's Flatpak remotes, only for the
browser; Settings > Apps lists it once installed but doesn't offer it. A daily check
updates every app a user installed, the browser included.

## Portable Apps (AppImage)

AppImage is a separate, per-user way to run portable apps outside the
Flatpak catalog.

Opening an AppImage offers three choices: **Run once**, **Add to Apps**, or
**Cancel**.

OS watches `Downloads`, `Desktop`, and any directories a user adds
explicitly. It detects new AppImage files by their actual content, not their
file extension, and shows one prompt per new file.
