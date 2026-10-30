# ShapeBit installer: agent and contributor rules

- **Verify with `ctest`.** A change is done only when `ctest --test-dir build`
  passes in the development container, and, for anything the real backend
  does, when `make test` passes in the image repository.
- **The backend owns every privileged operation.** The UI is unprivileged and
  reaches the backend only through `interface/installer.xml`. The backend
  builds every command line itself; nothing the frontend sends is executed.
- **Secrets never cross the control connection.** The owner password and the
  recovery key travel through one-shot channels that the backend creates. They
  never appear in plans, signals, errors, logs, or command arguments.
- **A disk is its identity, not its name.** Select, confirm, and erase by the
  stable id (WWN or serial). Re-resolve it immediately before the destructive
  step.
- **Prefer built-in tools.** Use what systemd, bootc, util-linux, and Qt
  already provide, such as `systemd-cryptenroll`, `homectl`, `lsblk --json`,
  and the generated D-Bus adaptor and proxy. Add a dependency only when
  nothing built in fits, and say why in a comment.
- **Every behavior gets a check.** Backend rules go in `tests/tst_backend.cpp`,
  the D-Bus interface in `tests/interface.sh`, pages in `tests/tst_ui.cpp`.
  Behavior on a real disk is checked by the image repository's tests.
- **Name files by function.** No product prefix in file names.
