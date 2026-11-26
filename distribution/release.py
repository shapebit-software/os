#!/usr/bin/env python3
"""How a build becomes a release (README.md): every step that the workflows
take with GHCR and GitHub's releases, so that the workflows only call it. Each
step lives with its part, where what it decides is tested: candidate.py,
channel.py, medium.py, and what they share in common.py. This file is only the
command line.

Usage, for developers and image builds:
  release.py pull-installer REF MEDIUM           a published medium, with its record, checked
  release.py sbom IMAGE DIR                      IMAGE's SBOM, in SPDX, into DIR

Usage, in the workflows (.github/workflows):
  release.py candidate VERSION IMAGE ARCHIVE UPDATE_ARCHIVE
      push a built candidate to os/candidate, with the build the update test
      moves on to, its sources and its SBOM; print its digest=, for GITHUB_OUTPUT
  release.py draft VERSION DIGEST [--bootstrap]
      replace the draft release with this tested candidate's, with its record
  release.py promote KEY
      release the draft's candidate: copy it, its sources and its SBOM to os,
      sign the image with KEY, the sigstore private key, and move stable to it
  release.py undo                                move stable back to the release before
  release.py prune                               delete what nobody may download any more
  release.py stable ARCHIVE SOURCES              os:stable, by digest, into ARCHIVE, with its
                                                 sources; print IMAGE= and VERSION=, for GITHUB_ENV
  release.py installer VERSION INSTALLER_IMAGE MEDIUM OS_SOURCES
      push a built medium and its sources to os/installer
  release.py installer-files VERSION DIR         a pushed medium and its sources, checked, as
                                                 the download server names them
"""

import sys

import candidate
import channel
import medium
import sbom

# Each command, with its arguments, and its optional flag.
COMMANDS = {
    "pull-installer": (2, None, medium.pull_installer),
    "sbom": (2, None, sbom.generate),
    "candidate": (4, None, candidate.candidate),
    "draft": (2, "--bootstrap", candidate.draft),
    "promote": (1, None, channel.promote),
    "undo": (0, None, channel.undo),
    "prune": (0, "--dry-run", channel.prune),
    "stable": (2, None, medium.stable),
    "installer": (4, None, medium.installer),
    "installer-files": (2, None, medium.installer_files),
}


def main(command=None, *args):
    count, flag, function = COMMANDS.get(command, (0, None, None))
    extra = args[count:]
    if function is None or len(args) < count or extra not in ((), (flag,)):
        sys.exit(__doc__)
    function(*args[:count], *([True] if extra else []))


if __name__ == "__main__":
    main(*sys.argv[1:])
