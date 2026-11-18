# Apps

Built-in apps, and installing others from Flathub: the package `shapebit-apps`.
The UI is Welcome and Settings > Apps in the shell; the work is done by
[app-catalog](app-catalog), [app-install](app-install), and
[app-remove](app-remove), through the [downloads](../downloads/README.md)
queue, and `app-update.timer` updates the apps daily.

## Rules

- **Built-in apps are RPMs in the image**, so everyone has the same versions
  and they update and roll back with the system: Files (Nautilus), as GNOME
  publishes no Flatpak of it, and Terminal (Ptyxis), as a terminal belongs
  outside a sandbox. Settings is the shell's. Screenshots and recordings
  belong to the shell, not to an app.
- **Everything else is a Flatpak**, installed per person. Welcome's
  recommended apps ([guidebook](../../guidebook/Apps.md)) are on by default.
- **Searches run locally**, on the catalogue Flatpak downloads.
- **Browsers** come from Flathub, but Chromium from Fedora's Flatpak
  ([fedora.filter](fedora.filter)). Chrome is Flathub's package, which
  downloads Google's build and checks it.
- **ShapeBit never redistributes a third party's binaries**: they come from
  Flathub or the vendor. Other remotes may come as an advanced, per-person
  option.

## Planned

- A second source in Settings > Apps: ShapeBit's own Flatpak repository
  ([release](../../release/README.md)).
- **Diagnostics**, a built-in app for processes and resources.
- **AppImage**: opening one offers **Run once**, **Add to Apps**, or
  **Cancel**; ShapeBit watches Downloads, Desktop, and added folders,
  recognizes AppImages by content, not name, and asks once per new file.
