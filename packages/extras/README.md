# Extras

Large optional downloads, such as speech and language models: the package
`shapebit-extras`. [extras.json](extras.json) lists them with their hashes,
sizes, credits, and licenses; [extra](extra) installs and removes them.

Rules:

- The image ships no model. What is too large for it, or not everyone needs,
  is an extra, kept apart from the sealed system, so the system needs none of
  them and updates without them.
- An extra is downloaded once for everyone on the computer, checked against
  its known hashes, and only administrators may add or remove it.
- Its license texts and credits are in the image, so Settings > Licenses
  shows them before it is downloaded, and each downloaded extra keeps them in
  its `NOTICE` ([packages/licenses](../licenses/README.md)).
