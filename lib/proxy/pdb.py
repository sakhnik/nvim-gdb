#!/usr/bin/env python3

"""
Run PDB in a pty.

This will allow to inject server commands not exposing them
to a user.
"""

import os
import re
import sys

from impl import Impl


class Pdb(Impl):
    """A proxy for the PDB backend."""

    def __init__(self, argv: [str]):
        """ctor."""
        super().__init__("PDB", argv)
        if sys.platform != 'win32':
            self.prompt = re.compile(rb"[\n\r]\(Pdb\+?\+?\) ")
        else:
            self.prompt = re.compile(rb"[\n\r]\(Pdb\+?\+?\) *")

    def get_prompt(self):
        return self.prompt


if __name__ == "__main__":
    # The script can be launched as `python3 script.py`
    args_to_skip = 0 if os.path.basename(__file__) == sys.argv[0] else 1
    pdb = Pdb(sys.argv[args_to_skip:])
    sys.exit(pdb.run())
