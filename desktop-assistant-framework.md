# Assistant Framework

**Status:** Draft

The assistant framework is the common local foundation for assistant and agent
interaction across ShapeBit Desktop. This document records intended behavior,
not implemented or verified desktop behavior.

## Scope

- Voice and chat are channels to the same framework, not separate assistants.
  The framework and its agents run locally.
- The initial product has one global assistant agent shared across all Workspaces
  and both channels.
- Context access, capabilities, privileges, and confirmations do not vary by
  input channel.

## Permissions and actions

- The assistant can access the current user's files, window contents, and
  clipboard without explicit per-item sharing. These read capabilities are
  granted by default to the initial agent.
- Access remains subject to the user's OS permissions and the framework's
  capability model; local execution bypasses neither.
- Permissions are assigned per agent and per capability, even while only one
  agent exists. One central permissions surface supports review and revocation.
- Write and control capabilities are disabled by default. ShapeBit requests a
  capability on first use, and an approved grant persists until revoked.
- Agents request typed actions through controlled APIs and cannot execute
  arbitrary shell commands.
- Reversible, non-destructive actions may run immediately. Destructive,
  privileged, or externally communicating actions require confirmation every
  time, regardless of persistent capability grants.

## History and memory

- The central assistant surface keeps a local activity log of requested and
  completed actions, confirmations, and permission changes.
- Log retention is user-configurable, and **Clear history** removes it
  immediately. Discarded voice audio and transcripts are never included.
- Assistant memory persists locally across voice and chat sessions. Users can
  view, edit, and clear it.
- Derived memories may survive a voice interaction, but raw audio and
  transcripts do not.

## Architecture constraint

The confirmed window-content goal does not yet distinguish semantic data
exposed by an application from captured screen pixels. Accepted
[ADR-0020](adr-0020-media-privacy-and-notifications.md)
requires a new portal selection for each screen-image capture and does not
retain that permission. Unrestricted pixel access is therefore not authorized
unless a later decision supersedes ADR-0020.

## Open decisions

Detailed capability scopes, the semantic-data versus screen-pixel boundary,
memory selection, and future agent isolation remain undecided. Cross-system
authorization constraints remain owned by the ShapeBit OS architecture and
decision records.
