# ADR-0022: Inbound File Sharing

**Status:** Accepted

**Date:** 2026-08-09

## Context

ShapeBit OS needs convenient file access from contemporary Windows, macOS,
and Linux computers without weakening its default-deny firewall, per-user
encrypted homes, or network-profile ownership model. Remote shell users already
have an SSH trust path, while desktop users expect native network-share
integration.

## Decision

### Initial service scope

SFTP is available whenever the system SSH server is configured and exposed on
the active network profile. It follows the SSH authentication and encrypted-home
lifecycle defined by ADR-0018.

ShapeBit additionally provides optional SMB sharing for explicitly selected
directories. SMB is disabled by default and is exposed only on saved network
profiles selected for each share. Guest and anonymous access are unavailable.

### Credentials and share roots

Each user has one SMB credential that is separate from the ShapeBit login
password, administrator credentials, SSH credentials, and Recovery Kit. Its
username matches the ShapeBit account name. ShapeBit generates a strong password
by default and lets the user replace it. The verifier is stored in the user's
encrypted home and is loaded into runtime service state only while that home is
active.

A user may share only an explicitly selected directory that they own inside
their active home. The UI does not offer one-click sharing of the entire home,
system paths, or another user's data. A symbolic link inside a share cannot
escape the selected root. A new share is read-only by default; write access
requires a separate explicit choice. Files created remotely are owned by the
user who owns the share.

The default share name is the selected directory's name and may be changed.
Names are unique across the computer and compared case-insensitively; the UI
suggests a numeric suffix when a name is already used. An authenticated user
sees only their own shares. mDNS advertises the SMB service, not individual
share names, and the UI provides a copyable address such as
`smb://computer/Projects`.

### Network exposure

A new share selects the current saved network profile by default. The user may
add or remove their own profiles through a trusted **Yes**/**No** confirmation
without an administrator password. Exposing a share on a system profile or a
profile owned by another user requires administrator authorization. A VPN must
be selected explicitly and is never inferred from its underlying network.

The firewall opens SMB only while an allowed profile is active. Explicitly
enabling a share is sufficient to advertise that service on its allowed
profiles even when general local-device discovery is disabled. It does not
enable general discovery queries or advertise unrelated ShapeBit services.

### Protocol security

SMB 3.0 is the minimum supported protocol. SMB 3.1.1 is negotiated when both
peers support it. Encryption is mandatory for every SMB connection. ShapeBit
uses direct-hosted SMB on TCP port 445 and does not expose SMB1, SMB2, NetBIOS,
or ports 137-139. Clients that cannot meet these requirements are rejected
rather than receiving a downgraded connection.

### Home and session lifecycle

Share configuration persists inside the encrypted home. After login, a share
starts automatically when an allowed profile is active unless the user disabled
automatic start or manually stopped that share. A manually stopped share stays
stopped until the user starts it again. Before home activation the share does
not exist and is not advertised.

An ordinary screen lock does not stop sharing. Before cryptographic suspend,
ShapeBit stops advertising, closes SMB access, and permits the home key to be
removed. Sharing resumes only after authentication and home unlock. Shares end
after the user's final session; an active SSH session intentionally keeps the
home and its shares active.

### Active transfers and concurrent access

The normal stop action rejects new work, lets current server-side operations
finish, synchronizes received data, and then closes the share. An explicit
immediate stop warns about active clients, synchronizes data already received,
disconnects clients, and closes the share. Logout and cryptographic suspend
attempt a graceful stop for a bounded period and then force closure so that a
faulty client cannot indefinitely block home deactivation. Exact operational
timeouts are selected from test evidence and do not change this contract.

ShapeBit cannot preserve changes that still exist only in a remote
application's memory. Standard SMB locking coordinates SMB clients. ShapeBit
does not add conflict copies or a separate synchronization protocol, and local
applications may still access shared files. The UI warns that simultaneous
local and remote editing may overwrite a newer version and shows active clients
and open files before a manual stop.

### Activity records

The default per-user record includes connection start and end, client address,
authentication success or rejection, share configuration and lifecycle events,
forced disconnects, and write errors. It does not record file names or file
contents. The record is kept in the user's encrypted home. Detailed diagnostic
logging is temporary and explicitly enabled. Repeated failed authentication is
rate-limited.

## Consequences

- Contemporary clients receive native SMB browsing with encrypted transport.
- Legacy SMB clients and older NAS devices are intentionally unsupported.
- A compromised SMB password does not reveal a login, administrator, or
  Recovery Kit credential.
- A share cannot make an inactive encrypted home reachable.
- Network-profile selection and firewall state remain the exposure boundary.
- ShapeBit protects server-received data during shutdown but cannot recover
  unsent remote application state or prevent every local-versus-remote edit
  conflict.

## Boundaries

This ADR owns inbound SFTP and SMB product scope, SMB credentials, share roots,
network exposure, protocol policy, share lifecycle, stopping semantics, and
default activity records. ADR-0011 owns home activation and encryption.
ADR-0018 owns SSH authentication and session lifetime. ADR-0021 owns network
profile ownership, discovery, and the default firewall policy. Capacity limits
and low-space behavior belong to D08.

## Related decisions

- [ADR-0011](ADR-0011-per-user-encrypted-homes.md)
- [ADR-0018](ADR-0018-desktop-session-and-authorization.md)
- [ADR-0021](ADR-0021-network-ownership-and-privacy.md)

## References

- [Microsoft SMB security enhancements](https://learn.microsoft.com/en-us/windows-server/storage/file-server/smb-security)
- [Microsoft SMB encryption requirements](https://learn.microsoft.com/en-us/windows-server/storage/file-server/configure-smb-client-require-encryption)
- [Samba `smb.conf` manual](https://www.samba.org/samba/docs/man/manpages/smb.conf.5.html)
