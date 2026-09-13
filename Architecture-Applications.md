# Applications

The OS combines a small set of built-in apps with a wide selection of
third-party software and support for portable AppImage apps.

## Built-in Apps

These apps ship as part of the OS image itself. Every user gets the same
versions, and they update and roll back together with the OS:

- **Settings**
- **Files**
- **Apps**
- **Text**
- **Terminal**
- **Diagnostics**

Each one has a defined scope, so it is clear which app owns a given task:

- **Files** handles archives, thumbnails, and a limited quick preview. Full
  PDF and image viewers, audio and video players, office suites, scanning
  apps, and browsers are installed separately as user apps.
- **Diagnostics** owns process and resource monitoring.
- **Settings** owns disk, storage, firmware, device, and printing
  configuration.
- The shell (not an app) owns screenshots and screen recording.

## Installing Apps

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
recommended app still has to be installed.

### Internet Browsers

On first login, an online user can pick a default browser from:

1. Google Chrome
2. Chromium
3. Firefox
4. GNOME Web

Nothing is preselected, and the step can be skipped, including while offline.
The chosen browser installs into that user's Flatpak installation and becomes
their default.

How each browser is packaged:

- **Chrome** — downloaded directly from Google and wrapped locally as a
  per-user Flatpak.
- **Chromium** — built from a fixed set of Fedora-signed RPMs (including split
  runtime packages), downloaded directly from Fedora and wrapped locally.
- **Firefox** and **GNOME Web** — installed from their regular Flathub
  packages.

## Portable Apps (AppImage)

AppImage is a separate, per-user way to run portable apps outside the
Flatpak catalog.

Opening an AppImage offers three choices: **Run once**, **Add to Apps**, or
**Cancel**.

OS watches `Downloads`, `Desktop`, and any directories a user adds
explicitly. It detects new AppImage files by their actual content, not their
file extension, and shows one prompt per new file.
