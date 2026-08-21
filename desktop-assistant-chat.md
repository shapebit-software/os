# Assistant Chat

**Status:** Draft

Assistant chat is a text interface to the shared local
[assistant framework](desktop-assistant-framework.md). This document records
intended behavior, not implemented or verified desktop behavior.

## Surface

- Chat is a global, on-demand overlay not owned by a Workspace.
- Chat is an independent, frameless overlay anchored at the bottom-left. It is
  not a pane or region inside the Shelf and does not use per-conversation
  chat-head icons.
- It opens from the system bar or a user-configurable shortcut and remains
  hidden when inactive.
- A bar button opens chat on that button's display; the shortcut uses the
  focused window's display. Only one global chat panel is open at a time.
- Clicking outside focused chat reduces it to the passive three-bubble state;
  clicking outside again while passive hides it. Escape or the close control
  hides it immediately. Hiding chat never ends the conversation or stops
  ongoing work; reopening restores the same conversation and position.
- The overlay is resizable from its top and right bounds, and its size is
  remembered per user. Most of its bounding area remains visually transparent.
- Opening chat alone does not hide the system bar. With a bottom bar, chat sits
  immediately above it; with a top bar, chat sits at the bottom-left edge.
- Chat and Shelf may remain open together. With the default bottom Shelf on the
  same display, chat moves above the Shelf preview immediately and farther
  upward when the full Shelf opens, then returns as those surfaces close.
  Moving the Shelf to another display does not move an already-open chat panel.
  Coexistence with a power-user Shelf edge remains to be refined.

## Bubble presentation

- Recent messages appear as floating bubbles above a compact input. Older
  messages remain available by scrolling within the overlay bounds.
- A small conversation header and the input appear when the overlay is hovered
  or receives keyboard focus. The header exposes the current title,
  conversation list, new-conversation action, and close control.
- Without hover or keyboard focus, the input and header hide and only the three
  most recent bubbles remain visible. Hover or focus restores the full
  scrollable conversation surface.
- Clicking a passive bubble focuses chat, restores its input and header, and
  expands the full conversation around that message.
- The keyboard shortcut and assistant system-bar icon share toggle semantics:
  hidden chat opens with the input focused; passive chat receives focus; an
  already focused chat hides.
- Focused and passive chat remain open across Workspace switches on the same
  display.
- Overview temporarily hides chat and restores its previous focused or passive
  state when Overview closes.
- A foreground fullscreen window temporarily hides chat on its display and
  restores it when fullscreen leaves. The explicit chat shortcut may still open
  chat above fullscreen when intentionally requested.
- If chat is completely hidden, a new assistant response never makes it appear
  automatically. The assistant system-bar control shows completion or attention
  instead. If chat is already open in its passive bubble state, the new response
  may appear there.
- Assistant responses stream progressively into one bubble. While a response or
  action is active, the Send control becomes **Stop**. Escape hides chat without
  stopping the agent.
- The input remains usable during active work. Sending another message adds it
  to the visible shared assistant queue rather than interrupting the current
  operation; queued items identify whether they came from chat or voice.
- Switching conversations never moves or cancels work. Every queued request and
  result remains attached to its originating conversation while another
  conversation may be visible.

## Conversations

- Multiple conversations and their messages persist locally until deleted.
- Each conversation has its own history, while assistant memory remains global
  across conversations.
- New conversations receive locally generated titles that users can rename.
- The conversation list is ordered by latest activity and supports local search
  across titles and messages.
- Deletion is immediate and confirmation-free, with a brief **Undo** action.

## Actions and confirmations

- Assistant tool and action requests appear as structured cards between message
  bubbles. Cards show pending, running, completed, or failed state rather than
  representing execution as ordinary assistant prose.
- A capability permission request and an individual action confirmation are
  separate cards. Granting a capability never also approves a destructive,
  privileged, or externally communicating action waiting behind it.
- When confirmation is required while chat is passive, the pending card remains
  visible among the three passive items and the assistant system-bar control
  marks attention. Chat does not take focus automatically. If chat is hidden,
  only the bar attention state appears until the user opens it.
- A completed action card collapses to a compact result summary with expandable
  details. The complete event also remains in the central assistant activity
  log defined by the shared framework.

Chat uses the same global assistant, memory, capabilities, privileges, and
confirmation rules as voice Assistant mode, all defined by the shared
[assistant framework](desktop-assistant-framework.md).
