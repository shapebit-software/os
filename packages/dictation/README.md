# Dictation

Speech to text, for dictation and the assistant: the package
`shapebit-dictation`. What a person sees is in the
[guide](../../guide/Dictation.md).

- [hear](hear) turns speech into words with sherpa-onnx (an external package,
  [sherpa-onnx/](sherpa-onnx/)) and Parakeet, an
  [extra](../extras/README.md). It runs as its own user service,
  `speech-model.service`, so dictation and the assistant's voice share one
  loaded model.
- [dictate](dictate) is the input method that delivers the words.

## Rules

- Words show only in the field they go to, as a draft, and go in only if the
  same field still has the focus, as text, not keys, so they can't trigger
  shortcuts. They are always copied too, so nothing is lost. Never into a
  password field, and never a new line.
- Each phrase is recognized once, when the person pauses, so nothing keeps the
  computer busy while they speak. At the stop, the whole recording is
  recognized again, in pieces of up to 15 seconds cut at its pauses, so that
  sentences hold together; a recording longer than a minute keeps its live
  phrases, to keep the wait short.
- Punctuation said as a word becomes its mark, except at the very start
  ("kropka nad i"); "period" always stays a word.
- Audio stays on the computer and is dropped when the dictation ends; the
  lock screen discards everything under way. An open microphone always shows
  on the bar.
- **Tidy up** is done by the assistant's model, and only replaces the text
  while the field still ends, at the cursor, with what was dictated;
  otherwise it is copied.
