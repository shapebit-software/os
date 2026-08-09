# ADR-0025: Enterprise Network Authentication

**Status:** Accepted

**Date:** 2026-08-09

## Context

ShapeBit OS needs a bounded initial set of enterprise Wi-Fi and VPN methods
without exposing every legacy NetworkManager plugin or allowing imported
configuration to execute host code. Enterprise credentials must follow the
user-owned and system-owned profile boundaries established by ADR-0021.

## Decision

### Enterprise Wi-Fi methods

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

### Certificate and password material

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

### Initial VPN protocols

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

### Import and executable configuration

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

### Server identity

WireGuard pins each peer's public key; endpoint-address changes do not replace
that cryptographic identity. OpenVPN requires a trusted CA, a server-appropriate
certificate, and an expected server name. IKEv2 requires a trusted CA and an
explicit server identity that matches its certificate.

The importer displays these identities before save. Missing identity data must
be completed rather than bypassed. An expired, revoked, untrusted, or
identity-mismatched certificate blocks the connection. Changing the configured
identity is an explicit profile edit; there is no connect-once exception for a
certificate error.

## Consequences

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

## Boundaries

This ADR owns initial enterprise Wi-Fi methods, VPN protocols, credential
formats, credential import, executable-configuration rejection, and server
identity validation. ADR-0021 owns profile ownership, activation, device-wide
VPN behavior, routing, DNS, kill switches, and firewall scope. ADR-0011 owns
encrypted-home activation. ADR-0018 owns administrator authorization.

## Related decisions

- [ADR-0011](ADR-0011-per-user-encrypted-homes.md)
- [ADR-0018](ADR-0018-desktop-session-and-authorization.md)
- [ADR-0021](ADR-0021-network-ownership-and-privacy.md)

## References

- [NetworkManager 802.1X settings](https://www.networkmanager.dev/docs/api/latest/settings-802-1x.html)
- [EAP-TLS with TLS 1.3](https://www.rfc-editor.org/rfc/rfc9190.html)
- [NetworkManager VPN support](https://networkmanager.dev/docs/vpn/)
- [NetworkManager WireGuard settings](https://networkmanager.dev/docs/api/latest/settings-wireguard.html)
- [strongSwan NetworkManager integration](https://docs.strongswan.org/docs/latest/features/networkManager.html)
