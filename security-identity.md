# Security and Identity

Encrypted system and user data, authentication and authorization, network ownership, remote access, sharing, enterprise credentials, and privacy boundaries.

These pages are living architecture, not implementation evidence. Unlabeled
sections describe the current design. A **Proposed** label marks a section that
still requires explicit review and validation; remove the label once that review
is complete.

Changing a current rule requires updating its owning section and every affected
cross-area contract.

## Architecture topics

## Per-User Encrypted Homes

**Date:** 2026-08-05

### Context

Each human user's home data must remain encrypted while that user is logged
out. Startup must not ask for one password to unlock storage and then ask for
the same password again to log in.

ShapeBit OS also plans to replace the initial TTY or conventional display
manager with a custom login screen. Storage encryption must therefore be tied
to the system authentication boundary, not to a particular login UI.

### Decision

- Human accounts use `systemd-homed` with one LUKS2 home container per user.
- The OS boots to a login surface without prompting for a user's home password.
- The user supplies one password through the PAM login conversation.
- `pam_systemd_home` uses that credential both to authenticate the user and to
  unlock and activate the user's home.
- The session starts only after the home is mounted successfully.
- The home is deactivated after the user's last session ends.
- Password changes must update the authentication credential and the LUKS2 key
  together through the supported PAM/systemd-homed path.
- Every user receives a separate recovery key during account creation. ShapeBit
  does not escrow the password or recovery key.
- System and service accounts are not managed by `systemd-homed`.

The future ShapeBit login screen will act as a PAM client. It must not implement
password verification, LUKS key derivation, or home mounting itself.

Inactive home-container files are persistent device state, initially stored
under `/var/lib/systemd/home/`. The system volume protects those files at the
physical-disk layer, but the separate per-user LUKS2 layer remains the authority
for access to an inactive home.

Each LUKS2 home uses Btrfs internally. Homes draw capacity from the protected
dynamic pool defined by [Initial Installation and Storage Profile](base-system.md) rather than fixed per-user partitions.

### Suspend authentication

ShapeBit exposes one user-facing **Require authentication after suspend**
setting, enabled by default.

Normal suspend remains the default laptop behavior; closing the lid does not
power off the device by default. [Display, Power, and Thermal Policy](desktop.md) defines detailed lid, docked-mode,
power-failure, and initial hibernation behavior.

When enabled, suspend locks both the desktop session and the active
`systemd-homed` home. The home key is removed from memory, access to the home is
suspended, and one authentication interaction restores both home access and the
session.

When disabled, both locks remain inactive so resume returns directly to the
session. The settings UI must warn that the active home key and session state
remain available in memory and that the full physical-access claim applies only
to a powered-off device. A future managed-device policy may force the setting
on.

### Secret handling

Account and storage policy may appear in `InstallationPlan`, but passwords and
recovery keys may not. Secrets use a separate short-lived channel, must not be
written to transaction logs, and must be cleared from memory as soon as the
authentication or enrollment operation completes.

### Consequences

- Each user's data remains unavailable while their home is inactive.
- Multiple users can unlock independent homes without a shared disk password.
- A forgotten password requires the user's recovery key or another previously
  enrolled credential; an administrator cannot bypass the encryption.
- Root can access a user's files while that home is active, so this protects
  data at rest rather than against a compromised running system.
- Login, logout, password change, recovery, backup, concurrent-session,
  suspend, and low-space behavior require integration tests.
- `/var` and other device state are protected by the TPM2-unlocked system
  volume defined in [TPM-Unlocked Encrypted System Volume](security-identity.md), without a
  routine second password prompt during normal startup.

### Boundaries

This section owns human-user home activation, recovery, filesystem choice, and
suspend authentication behavior. It does not define system-volume unlock or
grant the device recovery key access to any user's home.

## TPM-Unlocked Encrypted System Volume

**Date:** 2026-08-05

### Context

ShapeBit OS must protect machine configuration, service state, administrator
data, and the bootc deployment at rest without adding a routine password prompt
before the user login screen.

Per-user encrypted homes do not protect `/usr`, `/etc`, `/var`, `/root`, or
disk-backed swap. Those paths are required before a human user logs in and
therefore cannot be unlocked with one user's password.

### Decision

- The bootc physical root is stored in a system LUKS2 volume.
- The encrypted system volume covers `/usr`, `/etc`, `/var`, `/root`, and the
  backing files for inactive per-user home containers.
- Supported production hardware must provide TPM2.
- Normal boot unlocks the system volume automatically with a TPM2-enrolled key
  bound to the verified boot state.
- Every device receives a high-entropy recovery key for TPM failure, firmware
  changes, motherboard replacement, and repair workflows.
- Normal startup does not request the device recovery key or another system
  passphrase.
- The ESP and boot assets required by UEFI remain unencrypted. Their integrity
  and authorization are governed by [Boot Trust and TPM2 Unlock Policy](boot-system-lifecycle.md).
- Encryption is not a substitute for system integrity. OCI signatures, Secure
  Boot, signed UKIs, and deployment-integrity mechanisms remain required.

Per-user LUKS2 homes remain a second encryption layer governed by
[Per-User Encrypted Homes](security-identity.md). TPM activation of the system
volume does not activate any user's home.

### Swap

- Zram is the default swap mechanism and writes no swap contents to persistent
  storage.
- Any disk-backed swap must be encrypted.
- Disk swap without hibernation may use a fresh random key on every boot or
  reside inside the encrypted system volume.
- Hibernation requires a persistent encrypted resume area that can be unlocked
  in the initramfs. It cannot use a per-boot random key.
- Hibernation remains outside the first public release until encrypted resume,
  deployment compatibility, failed-resume cleanup, and lock-screen behavior
  pass end-to-end tests.

### Consequences

- A stolen powered-off disk does not expose system or user data.
- The normal user experience still contains only the login password prompt.
- TPM policy and recovery must be updated and tested across firmware, UKI,
  kernel, bootloader, and Secure Boot changes.
- Hardware without TPM2 cannot provide this normal-boot model and is not
  production-supported unless a later architecture section defines an equivalent mechanism.
- Development VMs may use explicitly marked test keys but cannot be treated as
  evidence of production security.

Boot-chain trust, update-compatible TPM2 authorization, key custody, rotation,
and revocation are specified by
[Boot Trust and TPM2 Unlock Policy](boot-system-lifecycle.md).

### Boundaries

This section requires encryption, automatic verified TPM2 unlock, and an independent
device recovery key. It does not select the filesystem inside the volume or the
PCR and signing policy used to authorize TPM2 unlock.

The outer system volume may contain inactive per-user home-container files. The
device recovery key unlocks only the outer system volume and never substitutes
for a user's credential or home recovery key.

## Network Ownership and Privacy

**Date:** 2026-08-08

### Context

ShapeBit OS must reconcile a system-wide network stack with independently
encrypted user homes. Wi-Fi and VPN credentials may belong to one user even
though an active connection changes connectivity, routing, and DNS for the
whole device. The initial design also needs explicit firewall, remote-access,
name-resolution, and local-discovery boundaries.

### Decision

#### Network stack and profile ownership

NetworkManager is the system network authority. Ethernet connectivity is
system-wide and may activate without a human login.

A new Wi-Fi profile belongs to the creating user by default. Its credentials
and private configuration are stored in that user's encrypted home and become
available only after home activation. An administrator may explicitly convert
or create a system-wide profile whose secrets are stored in encrypted system
state. A system profile may connect at the greeter and support system activity
before login.

Profile ownership protects configuration and credentials; it does not provide
per-user packet isolation. Once a user-owned Wi-Fi profile is active, system
services and every active session can use the resulting device-wide
connectivity. The connection ends after the owner's final session. Before
logout, ShapeBit warns if that disconnect would interrupt SSH, update transfer,
or other active network work. A system-owned profile is independent of user
session lifetime.

Wi-Fi uses a stable randomized MAC address per saved profile by default. This
keeps one address stable within a network without exposing the same hardware
address to unrelated networks. A profile may explicitly use the hardware MAC
when required by network access policy.

#### VPN ownership and kill switch

VPN routing is device-wide in the initial release. Per-user or per-application
network namespaces are deferred.

A VPN profile may belong to a user and keep its configuration and secrets in
that user's encrypted home. Its owner may activate or deactivate it from an
active local graphical session without an administrator password. SSH-only
presence is insufficient. The first activation explains that routing and DNS
change for the whole device. A later activation receives an additional
confirmation if it would affect another user's SSH session or critical network
work. The VPN disconnects after the owner's final session.

A system VPN is stored in encrypted system state, may operate before login, and
requires administrator authorization to create, change, or activate.

Each VPN profile may enable a kill switch, disabled by default. While the VPN
is expected to be active but its tunnel is unavailable, the firewall blocks all
traffic outside the tunnel except traffic required to reconnect. Local-network
traffic is blocked unless **Allow local network devices** is enabled. The block
also affects system services and other sessions. Intentional disconnect or the
owner's final logout releases the kill switch and restores ordinary routing.

#### DNS

NetworkManager supplies per-link configuration to `systemd-resolved`, which is
the system DNS resolver. Split DNS uses routing domains so private VPN domains
are sent only to the VPN resolver. A full-tunnel VPN owns the default DNS route.
Queries assigned to a VPN do not fall back to ordinary Wi-Fi or Ethernet DNS,
and a VPN kill switch covers DNS traffic.

Strict DNS-over-TLS may be configured per profile. A user may configure it for
their own profile; an administrator may configure it for a system profile. A
strict failure is reported as DNS failure and never silently falls back to
plaintext. ShapeBit does not present opportunistic DNS-over-TLS as a privacy
feature because it permits downgrade.

System-wide DNS-over-HTTPS is outside the initial release. Applications such as
browsers may implement their own DoH, but ShapeBit documents that it bypasses
system split-DNS routing and resolver leak controls.

#### Firewall, SSH, and discovery

The system firewall denies unsolicited inbound network traffic by default and
allows replies to connections initiated by the device. Applications may make
outbound connections and bind local sockets, but binding does not automatically
publish a port to the network. Applications cannot persistently rewrite the
firewall; system policy owns all exceptions.

Enabling the system SSH server does not expose it on every interface. An
administrator enables incoming SSH separately for selected saved network
profiles, with the current profile selected by default during setup. The
firewall exception exists only while an allowed profile is active. The UI lists
the active profiles and addresses on which SSH is reachable. Authentication and
encrypted-home behavior remain defined by [Desktop Session and Authorization Boundaries](desktop.md).

Local mDNS discovery is disabled on a new profile. The profile owner may enable
**Discover devices on this network** without an administrator password. This
allows discovery queries and replies while that profile is active but does not
advertise the computer name or any ShapeBit service. A service is advertised
only after its own explicit sharing action. LLMNR remains disabled.

#### Captive portals

The initial release provides no dedicated captive-portal detection, login UI,
or greeter flow. A portal may happen to work through an ordinary browser after
login, but ShapeBit does not claim or test that as a supported workflow.

### Consequences

- User-owned secrets remain unavailable while their encrypted home is inactive.
- User-owned Wi-Fi and VPN profiles still change connectivity for the whole
  device while active.
- Background updates before login require Ethernet or a system-owned network
  profile.
- The VPN kill switch can intentionally make every session and system service
  appear offline.
- Strict per-link and split DNS avoid silent VPN DNS fallback.
- Incoming services, SSH, and local discovery require separate deliberate
  enablement.
- Networks that require a captive portal are outside the initial supported
  connectivity scope.

### Boundaries

This section owns network-profile secret placement, profile lifetime, device-wide
VPN semantics, DNS routing, firewall defaults, SSH network exposure, MAC
randomization, discovery, and captive-portal scope. [Desktop Session and Authorization Boundaries](desktop.md) owns SSH
authentication and graphical versus remote session lifecycles. [Staged Stable Rollout](boot-system-lifecycle.md) owns
when update artifacts may be downloaded over an available network. [Inbound File Sharing](security-identity.md)
defines file-sharing services and selects the network profiles on which they
are exposed. [Enterprise Network Authentication](security-identity.md) defines supported enterprise authentication methods and
credential formats.

## Inbound File Sharing

**Date:** 2026-08-09

### Context

ShapeBit OS needs convenient file access from contemporary Windows, macOS,
and Linux computers without weakening its default-deny firewall, per-user
encrypted homes, or network-profile ownership model. Remote shell users already
have an SSH trust path, while desktop users expect native network-share
integration.

### Decision

#### Initial service scope

SFTP is available whenever the system SSH server is configured and exposed on
the active network profile. It follows the SSH authentication and encrypted-home
lifecycle defined by [Desktop Session and Authorization Boundaries](desktop.md).

ShapeBit additionally provides optional SMB sharing for explicitly selected
directories. SMB is disabled by default and is exposed only on saved network
profiles selected for each share. Guest and anonymous access are unavailable.

#### Credentials and share roots

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

#### Network exposure

A new share selects the current saved network profile by default. The user may
add or remove their own profiles through a trusted **Yes**/**No** confirmation
without an administrator password. Exposing a share on a system profile or a
profile owned by another user requires administrator authorization. A VPN must
be selected explicitly and is never inferred from its underlying network.

The firewall opens SMB only while an allowed profile is active. Explicitly
enabling a share is sufficient to advertise that service on its allowed
profiles even when general local-device discovery is disabled. It does not
enable general discovery queries or advertise unrelated ShapeBit services.

#### Protocol security

SMB 3.0 is the minimum supported protocol. SMB 3.1.1 is negotiated when both
peers support it. Encryption is mandatory for every SMB connection. ShapeBit
uses direct-hosted SMB on TCP port 445 and does not expose SMB1, SMB2, NetBIOS,
or ports 137-139. Clients that cannot meet these requirements are rejected
rather than receiving a downgraded connection.

#### Home and session lifecycle

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

#### Active transfers and concurrent access

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

#### Activity records

The default per-user record includes connection start and end, client address,
authentication success or rejection, share configuration and lifecycle events,
forced disconnects, and write errors. It does not record file names or file
contents. The record is kept in the user's encrypted home. Detailed diagnostic
logging is temporary and explicitly enabled. Repeated failed authentication is
rate-limited.

### Consequences

- Contemporary clients receive native SMB browsing with encrypted transport.
- Legacy SMB clients and older NAS devices are intentionally unsupported.
- A compromised SMB password does not reveal a login, administrator, or
  Recovery Kit credential.
- A share cannot make an inactive encrypted home reachable.
- Network-profile selection and firewall state remain the exposure boundary.
- ShapeBit protects server-received data during shutdown but cannot recover
  unsent remote application state or prevent every local-versus-remote edit
  conflict.

### Boundaries

This section owns inbound SFTP and SMB product scope, SMB credentials, share roots,
network exposure, protocol policy, share lifecycle, stopping semantics, and
default activity records. [Per-User Encrypted Homes](security-identity.md) owns home activation and encryption.
[Desktop Session and Authorization Boundaries](desktop.md) owns SSH authentication and session lifetime. [Network Ownership and Privacy](security-identity.md) owns network
profile ownership, discovery, and the default firewall policy. Capacity limits
and low-space behavior belong to D08.

## Enterprise Network Authentication

**Date:** 2026-08-09

### Context

ShapeBit OS needs a bounded initial set of enterprise Wi-Fi and VPN methods
without exposing every legacy NetworkManager plugin or allowing imported
configuration to execute host code. Enterprise credentials must follow the
user-owned and system-owned profile boundaries established by [Network Ownership and Privacy](security-identity.md).

### Decision

#### Enterprise Wi-Fi methods

The initial 802.1X Wi-Fi set is:

- EAP-TLS with a client certificate;
- PEAP with inner EAP-MSCHAPv2;
- EAP-TTLS with inner PAP or EAP-MSCHAPv2.

TLS 1.2 is the minimum accepted tunnel version and TLS 1.3 is negotiated when
both peers support it. Every profile requires a trusted CA and an expected
server name or domain suffix. ShapeBit does not expose a bypass for server
certificate validation.

LEAP, EAP-MD5, EAP-FAST, EAP-PWD, EAP-SIM, and EAP-AKA are outside the initial
scope. Their exclusion covers obsolete password methods, vendor-specific
provisioning, and SIM-backed carrier workflows rather than declaring every use
of those methods impossible.

#### Certificate and password material

Software-held credentials initially support:

- PKCS#12 `.p12` and `.pfx` containers;
- separate PEM certificates and private keys;
- separate CA certificates; and
- password-protected private keys.

Smart cards, YubiKey-style tokens, and other PKCS#11 private-key providers are
deferred. The same software certificate formats apply to Wi-Fi and VPN.

Import copies certificates, keys, and referenced files into the managed profile
credential store so the connection does not depend on a file remaining in
`Downloads`. ShapeBit never removes the original user file automatically.
Removing the profile removes its managed copies, not the originals.

A user-owned profile stores credentials in that user's encrypted home. Remember
is the default so automatic reconnection works. The user may select **Ask every
time**, which prevents unattended activation until the secret is supplied. A
system profile stores required credentials in encrypted system state and
requires administrator authorization. Passwords, private keys, private-key
passwords, and one-time values are excluded from ordinary configuration output,
logs, and diagnostics.

#### Initial VPN protocols

The initial VPN set is:

- WireGuard, using NetworkManager's native support;
- OpenVPN through the NetworkManager OpenVPN plugin; and
- IKEv2 through the NetworkManager strongSwan plugin.

PPTP, IKEv1, `vpnc`, L2TP/IPsec, SSTP, vendor-specific SSL VPNs, and
OpenConnect/AnyConnect are deferred.

WireGuard supports a client private key, peer public keys, and an optional
per-peer preshared key. OpenVPN supports CA and client certificates, PKCS#12 or
PEM private keys, username and password, certificate plus username and password,
`tls-auth`, `tls-crypt`, and an interactive one-time code or challenge response.
One-time values are never stored. IKEv2 supports client certificate
authentication, EAP-TLS, EAP-MSCHAPv2 username and password, and an optional
long preshared key with a warning that certificate authentication is preferred.

#### Import and executable configuration

WireGuard imports standard `.conf` files. OpenVPN imports `.ovpn` files,
including embedded certificates and keys. Externally referenced files are
copied into the managed profile store. IKEv2 is configured manually in the
initial UI because there is no single interoperable import format.

Before saving, the UI previews the endpoint, DNS, routes, full-tunnel or
split-tunnel behavior, and imported credential classes. The imported profile
belongs to the importing user by default.

The importer accepts declarative configuration only and never executes content
while parsing. WireGuard `PreUp`, `PostUp`, `PreDown`, and `PostDown` commands
are rejected. OpenVPN scripts, executable hooks, and binary plugins are
rejected. Unsupported executable content is reported precisely; ShapeBit does
not silently ignore or rewrite it. Supporting sandboxed executable extensions
is not part of the initial VPN contract.

#### Server identity

WireGuard pins each peer's public key; endpoint-address changes do not replace
that cryptographic identity. OpenVPN requires a trusted CA, a server-appropriate
certificate, and an expected server name. IKEv2 requires a trusted CA and an
explicit server identity that matches its certificate.

The importer displays these identities before save. Missing identity data must
be completed rather than bypassed. An expired, revoked, untrusted, or
identity-mismatched certificate blocks the connection. Changing the configured
identity is an explicit profile edit; there is no connect-once exception for a
certificate error.

### Consequences

- The initial Wi-Fi set covers certificate-based, common Microsoft-backed, and
  common academic enterprise deployments.
- Software certificates work without adding token, reader, PIN, and suspend
  lifecycle complexity.
- WireGuard, OpenVPN, and IKEv2 cover modern key-based, portable, and enterprise
  VPN use without enabling every legacy or vendor-specific plugin.
- Strict server validation prevents convenience overrides from turning a
  credential prompt into credential disclosure to an impostor.
- Declarative-only import rejects some existing configurations that depend on
  arbitrary host scripts or plugins.
- User-owned secrets remain unavailable while their encrypted home is inactive.

### Boundaries

This section owns initial enterprise Wi-Fi methods, VPN protocols, credential
formats, credential import, executable-configuration rejection, and server
identity validation. [Network Ownership and Privacy](security-identity.md) owns profile ownership, activation, device-wide
VPN behavior, routing, DNS, kill switches, and firewall scope. [Per-User Encrypted Homes](security-identity.md) owns
encrypted-home activation. [Desktop Session and Authorization Boundaries](desktop.md) owns administrator authorization.
