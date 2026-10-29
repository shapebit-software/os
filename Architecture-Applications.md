# Applications

The OS combines a small set of built-in apps with a wide selection of
third-party software and support for portable AppImage apps.

## Built-in Apps

These apps ship as part of the OS image itself. Every user gets the same
versions, and they update and roll back together with the OS:

- **Settings**
- **Files** (Nautilus, Fedora's RPM: GNOME publishes no Flatpak of it)
- **Apps**
- **Diagnostics**

Each one has a defined scope, so it is clear which app owns a given task:

- **Files** handles archives and thumbnails.
- **Diagnostics** owns process and resource monitoring.
- **Settings** owns disk, storage, firmware, device, and printing
  configuration.
- The shell (not an app) owns screenshots and screen recording.

Settings is part of the shell. Apps and Diagnostics are not built yet.

## Recommended Apps

On first login, Welcome ([Desktop](Architecture-Desktop#welcome)) installs
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
Flatpak adds by itself on first use. The Apps installer below is not built
yet.

The Apps installer shows exactly two sources:

- **Flathub**, for third-party applications.
- The **OS repository**, for apps and integration packages that
  OS itself builds and maintains.

The OS repository may contain own binaries, but it never
stores, mirrors, or redistributes a third party's binaries — those always
come from Flathub or the vendor directly.

Adding other Flatpak remotes is possible, but it is an advanced, per-user
option that most users won't need.

**Recommendations** is a manually curated, signed list maintained by
OS. Nothing outside the OS image's built-in apps is preinstalled — every
recommended app still has to be installed. Until the Apps installer exists,
Welcome's recommended apps are the list.

### Internet Browsers

On first login, Welcome
([Desktop](Architecture-Desktop#welcome)) lets an online user pick a default
browser from:

1. Google Chrome
2. Chromium
3. Firefox
4. GNOME Web

Nothing is preselected, and the step can be skipped, including while offline.
The chosen browser installs into that user's Flatpak installation and becomes
their default.

How each browser is packaged:

- **Chrome** — Google's official RPM, downloaded directly from Google,
  checked against Google's signing key, and wrapped locally as a per-user
  Flatpak on Fedora's Flatpak runtime. Its sandbox runs through zypak, which
  the OS image builds from source. A daily check rebuilds it when Google
  publishes a new release or the image moves to a new Fedora version.
- **Chromium** — Fedora's official Flatpak, from Fedora's registry
  (registry.fedoraproject.org), built by Fedora from its own packages.
- **Firefox** and **GNOME Web** — installed from their regular Flathub
  packages.

Chrome and Chromium add Fedora's registry, and Chrome also a local
repository, to that user's Flatpak remotes, only for the browser; the Apps
installer doesn't show them as sources.

## Portable Apps (AppImage)

AppImage is a separate, per-user way to run portable apps outside the
Flatpak catalog.

Opening an AppImage offers three choices: **Run once**, **Add to Apps**, or
**Cancel**.

OS watches `Downloads`, `Desktop`, and any directories a user adds
explicitly. It detects new AppImage files by their actual content, not their
file extension, and shows one prompt per new file.
