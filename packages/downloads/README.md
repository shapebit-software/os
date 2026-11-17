# Downloads

The one queue of everything the desktop downloads and installs: the package
`shapebit-downloads`.

Everything goes through [downloads](downloads): the browser and apps from
Welcome, installs and removals in Settings > Apps, extras, and the daily app
updates. One job runs at a time, outside the shell, so it goes on if the
shell restarts; `downloads.service` resumes what a logout stopped at the next
sign-in, and a download goes on where it stopped. The shell only shows the
queue (Notifications, Settings > Downloads), from
`~/.local/state/desktop/downloads.json`.
