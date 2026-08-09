# ADR-0021: Network Ownership and Privacy

**Status:** Accepted

**Date:** 2026-08-08

## Context

ShapeBit OS must reconcile a system-wide network stack with independently
encrypted user homes. Wi-Fi and VPN credentials may belong to one user even
though an active connection changes connectivity, routing, and DNS for the
whole device. The initial design also needs explicit firewall, remote-access,
name-resolution, and local-discovery boundaries.

## Decision

### Network stack and profile ownership

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

### VPN ownership and kill switch

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

### DNS

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

### Firewall, SSH, and discovery

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
encrypted-home behavior remain defined by ADR-0018.

Local mDNS discovery is disabled on a new profile. The profile owner may enable
**Discover devices on this network** without an administrator password. This
allows discovery queries and replies while that profile is active but does not
advertise the computer name or any ShapeBit service. A service is advertised
only after its own explicit sharing action. LLMNR remains disabled.

### Captive portals

The initial release provides no dedicated captive-portal detection, login UI,
or greeter flow. A portal may happen to work through an ordinary browser after
login, but ShapeBit does not claim or test that as a supported workflow.

## Consequences

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

## Boundaries

This ADR owns network-profile secret placement, profile lifetime, device-wide
VPN semantics, DNS routing, firewall defaults, SSH network exposure, MAC
randomization, discovery, and captive-portal scope. ADR-0018 owns SSH
authentication and graphical versus remote session lifecycles. ADR-0009 owns
when update artifacts may be downloaded over an available network.

## Open questions

- Whether the initial release provides inbound file sharing through SMB, uses
  only SFTP through SSH, or defers all built-in file serving.
- Detailed enterprise Wi-Fi and VPN credential types supported initially.

## Related decisions

- [ADR-0009](ADR-0009-staged-rollout.md)
- [ADR-0011](ADR-0011-per-user-encrypted-homes.md)
- [ADR-0018](ADR-0018-desktop-session-and-authorization.md)

## References

- [systemd-resolved configuration](https://www.freedesktop.org/software/systemd/man/devel/resolved.conf.html)
- [NetworkManager DNS and routing settings](https://networkmanager.dev/docs/api/latest/settings-ipv4.html)
