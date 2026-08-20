# Assistant Chat

**Status:** Draft

Assistant chat is a text interface to the shared local
[assistant framework](desktop-assistant-framework.md). This document records
intended behavior, not implemented or verified desktop behavior.

## Surface

- Chat is a global, on-demand overlay not owned by a Project.
- It opens from the system bar or a user-configurable shortcut and remains
  hidden when inactive.
- Escape or clicking outside hides it without ending the conversation or
  stopping ongoing work. Reopening restores the same conversation and
  position.

## Conversations

- Multiple conversations and their messages persist locally until deleted.
- Each conversation has its own history, while assistant memory remains global
  across conversations.
- New conversations receive locally generated titles that users can rename.
- The conversation list is ordered by latest activity and supports local search
  across titles and messages.
- Deletion is immediate and confirmation-free, with a brief **Undo** action.

Chat uses the same global assistant, memory, capabilities, privileges, and
confirmation rules as voice Assistant mode, all defined by the shared
[assistant framework](desktop-assistant-framework.md).
