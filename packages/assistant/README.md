# Assistant

The assistant's service, its actions, skills, and model catalog, the model
server, and what the shell shows of it: the package `shapebit-assistant`.
What a person sees is in the [guidebook](../../guidebook/Assistant.md).

Its user interface is its own QML, the module `qs.assistant`
([src/shell/](src/shell/)): the bubbles, the panel and the docked panel, the
voice pill, its button, and Settings > Assistant with its pages. The package
installs it in the shell's folder, with [feature.qml](src/feature.qml), which
says what it adds to the shell ([Features](../shell/src/services/Feature.qml)):
the shell names no assistant. Its settings in the desktop are kept in
`~/.config/desktop/assistant.json`. `make lint` checks its QML against the shell's
modules.

One service ([assistant](src/assistant), `assistant.socket`) serves the whole
session, outside the shell. The local model, Gemma 4 E2B, runs in
`llama-server` (an external package, [llama-server/](external/llama-server/)), started
on demand by `language-model@.socket`; the model itself is an
[extra](../extras/README.md). Speech comes from dictation's speech model
([packages/dictation](../dictation/README.md)).

## Rules

- **Typed actions only** ([actions.py](src/actions.py)), never a command the model
  writes. Each has a risk: **Read** runs at once; **See** (windows, pictures
  of the screen, the web) and **Change** ask on their card until the person
  allows the group; **Confirm** (power, installing or removing apps) asks
  every time. A change can be undone from its card. Typed and spoken requests
  share one queue; stopping one never rolls back what is done.
- **Untrusted input.** Everything beside the person's words, such as the
  selected text, window titles, and what actions return, is information,
  never a request, and the model is told so. A text can still ask the model
  for something, so a change or a web lookup in a request that carries any of
  it asks on its card, even in an allowed group. In voice mode, "yes" can
  approve only a change: See and Confirm need a click, as a video or someone
  nearby can say "yes" too.
- **The web** ([web.py](src/web.py)) reaches only public addresses, redirects
  too, and nothing (not even a DNS lookup) happens before it is allowed. No
  page's JavaScript runs.
- **Context sent** is only the selected text and the focused window's app and
  title, shown before sending. Pictures of the screen go to the model for
  that request only, and aren't kept.
- **Online providers** only as their terms allow ([providers.py](src/providers.py)):
  OpenAI through "Sign in with ChatGPT" ([chatgpt.py](src/chatgpt.py)), which
  OpenAI allows for open-source and local apps, showing "Using ChatGPT plan"
  with **Manage usage** as OpenAI asks, or an API key; Claude and Gemini only
  with an API key, as Anthropic and Google forbid apps to sign in with their
  plans. Keys stay in the keyring; removing a provider's last model forgets
  its key, and signing out revokes the ChatGPT sign-in.
- **AI disclosure** (EU AI Act, article 50): it always says that an AI
  answers, and that answers can be wrong.
- **The prompt** stays the same between requests, so a local model keeps it
  processed: instructions, actions, and the computer's facts; the time comes
  from an action. Skills ([skills/](data/skills/)) keep it short: only their names
  and descriptions are in it, and the model reads one when needed. A skill can
  set the temperature (writing 0.8, everything else 0.2). Built-in skills are
  read-only; a person's own are in `~/.config/assistant/skills`.
- **Voice mode**'s conversation lives in memory only, never listed or saved.
  Smart Turn, from the Dictation extra, decides from the voice whether a
  sentence is over; without it, the words decide.
- Locking the screen hides it, and nothing new starts until unlock.

## Not yet implemented

Memory across conversations, reading a window's contents, files, or the
clipboard, and web search beyond Wikipedia, which waits for a provider.
