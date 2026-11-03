# Applications

ShapeBit combines a small set of built-in apps with apps from Flathub.

## Built-in Apps

Built-in apps are part of the system image: everyone gets the same versions,
and they update and roll back with the system. Each owns its tasks:

- **Settings**, part of the shell: device, display, network, and account
  configuration, and installing apps.
- **Files** (Nautilus): files, archives, and thumbnails. It is Fedora's
  package, as GNOME publishes no Flatpak of it.
- **Diagnostics**: processes and resources. Not built yet.

Screenshots and screen recording belong to the shell, not to an app.

## Recommended Apps

On first login, Welcome ([Desktop](Architecture-Desktop.md#welcome)) offers
these apps from Flathub, all on, each with a switch to leave it out:

- **Terminal** (Ptyxis)
- **Text Editor** (GNOME Text Editor)
- **Image Viewer** (Loupe)
- **Document Viewer** (Papers)
- **Video Player** (Showtime)
- **Audio Player** (Decibels)
- **Calculator** (GNOME Calculator)

They open their file types by default. Office suites, scanners, media
editors, and browsers are installed separately.

## Installing Apps

**Settings > Apps** is the app store: all apps, verified ones first, with a
search, categories, and a view of the installed ones. Apps install into the
person's own account, through the desktop's one
[queue of downloads](Architecture-Desktop.md#downloads). Searches run on the
computer, on the catalogue Flatpak downloads, so what someone looks for isn't
sent anywhere.

Removing an app asks first, keeps its data unless told to delete it, and then
removes what no other app uses. Built-in apps can't be removed. Every app a
person installed updates daily in the background.

Apps is to show two sources; today it shows Flathub:

- **Flathub**, for third-party apps.
- The **OS repository**, for apps and integration that ShapeBit builds
  ([Distribution](Architecture-Lifecycle.md#distribution)). Not built yet.

The OS repository never stores or redistributes a third party's binaries;
those come from Flathub or the vendor. Other Flatpak remotes are possible, as
an advanced, per-person option.

### Internet Browsers

When online, Welcome lets a person pick a default browser; none is picked at
first, and none has to be:

| Browser | Comes from |
|---|---|
| Google Chrome | Flathub's package, which downloads Google's own build and checks it |
| Chromium | Fedora's Flatpak, built by Fedora |
| Firefox | Flathub |
| GNOME Web | Flathub |

The chosen browser installs into that person's account and becomes their
default.

## Portable Apps (AppImage)

> **Planned.** Not built yet.

AppImages are a separate, per-person way to run portable apps. Opening one
offers **Run once**, **Add to Apps**, or **Cancel**. ShapeBit watches
Downloads, Desktop, and folders a person adds, recognizes AppImages by their
content rather than their name, and asks once per new file.
