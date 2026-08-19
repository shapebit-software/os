# ADR-0018: Desktop Session and Authorization Boundaries

**Status:** Accepted

**Date:** 2026-08-08

**Last updated:** 2026-08-10

## Context

ShapeBit OS needs a custom Wayland desktop that can recover from ordinary UI
failures without turning display components into privileged policy engines. Its
per-user encrypted homes also require login, lock, local authorization, and
remote access to share one coherent session lifecycle.

## Decision

### Desktop process model

Each graphical user session contains:

- one minimal compositor responsible for Wayland objects, outputs, input, and
  the authoritative locked/unlocked state;
- one restartable shell process containing the panel, launcher, notifications,
  and primary desktop UI;
- a separate trusted lock component;
- a separate trusted authorization agent.

A shell failure does not terminate applications or unlock the session. The
user service manager restarts the shell. The compositor retains the locked
state if the lock UI fails and restarts the lock component without exposing
the desktop.

The greeter runs in a separate system session with a separate compositor
process. It may reuse the same compositor implementation, but never the same
process or user authority as a logged-in desktop. Every graphical user session
receives its own compositor process.

ShapeBit initially permits only one logged-in graphical user session at a time.
Changing graphical user requires logout; fast user switching is deferred.
Non-graphical SSH sessions are not counted as graphical sessions.

### Compositor failure

Wayland applications are not promised transparent reconnection after a
compositor failure. ShapeBit terminates the damaged graphical session, closes
its remaining processes, deactivates the home when no other session still uses
it, returns to the independent greeter, and records a diagnostic report.

Preserving unsaved work is an application-level recovery property. ShapeBit
system applications must provide continuous autosave and recovery where their
data model permits it. ShapeBit does not use process checkpointing and does not
guarantee recovery for third-party applications.

### Privilege and account model

The compositor, shell, lock UI, authorization UI, and settings UI run without
root privileges. Narrow system services perform privileged work through
versioned D-Bus APIs. Polkit decides whether the active caller may authorize a
request. ADR-0030 defines service names, caller-identity evidence,
authorization classes, versioning, errors, and job lifecycle.

The first human account created during installation is an administrator.
Additional accounts may be standard users or administrators. Administrator
applications still run unprivileged. A standard user's own password does not
authorize an administrator-only operation.

Direct login as `root` is disabled and the root account has no login password.
Administrative terminal work uses `sudo`; graphical work uses Polkit. Recovery
Kit credentials unlock encrypted data or recovery operations and do not grant
an administrator role.

The trusted authorization agent receives credentials directly for PAM/Polkit,
shows the exact requester and operation, and obtains compositor-controlled
exclusive input. A successful Polkit authentication is cached for a fixed five
minutes. Later requests do not extend that deadline. Every privileged request
during the cached period still receives a trusted **Yes**/**No** confirmation
that identifies the requester and operation. Lock, logout, or session
termination clears the cache immediately. Polkit and `sudo` caches are
independent.

The system-wide battery charge limit is a specific low-risk exception: only an
active local administrator may change it, but the trusted confirmation does not
request a password.

### Developer mode and SSH

Developer mode is a per-user presentation and tooling setting. It may expose a
terminal, advanced application controls, and diagnostic logs, but does not
disable Secure Boot, update verification, or other system protections. Test
channels and local system-trust keys are separate administrator-authorized
system operations with explicit warnings.

The system SSH server is disabled by default and developer mode does not enable
it. Enabling or changing it is an administrator-authorized system operation.
Direct root login and password-only SSH login are disabled.

SSH public keys are stored in the `systemd-homed` user record so they can be
resolved while the encrypted home is inactive. Login behaves as follows:

- if the user's home is already active, the enrolled SSH key is sufficient;
- if the home is inactive, the key must succeed first and PAM then requests the
  user's normal password to unlock the home;
- a Recovery Kit credential is never accepted over SSH.

SSH sessions may coexist with the one graphical session. Local graphical logout
does not kill SSH sessions; the home remains active until the user's final
session ends. The logout UI reports active remote sessions and offers either
local graphical logout or termination of all sessions owned by that user.

## Consequences

- Routine shell and lock-UI failures have bounded effects.
- A compositor failure may lose unsaved third-party application state even
  though the system returns to a secure greeter.
- UI compromise does not itself grant root authority.
- Short-lived authorization caching improves usability while keeping every
  operation visible.
- Remote login to an inactive encrypted home requires both an SSH key and the
  home password.
- Active SSH work intentionally keeps that user's encrypted home unlocked.

## Boundaries

This ADR owns desktop process isolation, graphical session cardinality,
compositor-failure recovery, local authorization, administrator roles,
developer-mode security invariants, and SSH interaction with encrypted homes.
ADR-0011 remains authoritative for home encryption and PAM-based activation.
ADR-0021 defines the network profiles on which SSH is exposed.

## Related decisions

- [ADR-0011](ADR-0011-per-user-encrypted-homes.md)
- [ADR-0015](ADR-0015-microsoft-shim-and-trust-domains.md)
- [ADR-0023](ADR-0023-application-platform-and-system-set.md)
- [ADR-0021](ADR-0021-network-ownership-and-privacy.md)
- [ADR-0030](ADR-0030-platform-service-api-contract.md)

## References

- [systemd-homed and PAM](https://www.freedesktop.org/software/systemd/man/latest/pam_systemd_home.html)
- [systemd JSON user records](https://systemd.io/USER_RECORD/)
- [OpenSSH authentication methods](https://man.openbsd.org/sshd_config)
- [Wayland protocol model](https://wayland.freedesktop.org/docs/book/Protocol.html)
