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
- The global agent has one serialized request queue shared by voice Assistant
  mode and chat. Requests retain their source channel and run in arrival order.
- Cancelling the current request stops that operation and then allows the next
  queued request to begin. Cancellation does not silently discard the queue.
- Cancellation stops generation and requests cancellation from an active action
  only when that action supports it. It never rolls back completed effects and
  clearly reports when an in-progress action cannot be interrupted.
- A non-interruptible action continues to hold the serialized queue until it
  finishes; later requests never run concurrently through the same agent.
- The assistant system-bar control shows current activity and the number of
  queued requests, including while chat is hidden.
- Locking the session hides all assistant output. Already-authorized local work
  may continue, but results are exposed only after unlock. Requests that have
  not started remain paused in the queue until the session unlocks.
- Work that reaches a permission or confirmation step while locked pauses and
  presents the card only after unlock.

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
- Capability grants and required action confirmations must be activated through
  the visible card with pointer or keyboard input. Spoken confirmation is not
  sufficient in the initial design.

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
