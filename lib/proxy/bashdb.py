#!/usr/bin/env python3

"""
Run bashdb in a pty.

This will allow to inject server commands not exposing them
to a user.
"""

import os
import re
import sys

from impl import Impl


class BashDb(Impl):
    """PTY proxy for bashdb."""

    def __init__(self, argv: [str]):
        """ctor."""
        super().__init__("BashDB", argv)
        self.prompt = re.compile(rb'[\r\n]bashdb<\(?\d+\)?> ')

    def get_prompt(self):
        return self.prompt


if __name__ == "__main__":
    # The script can be launched as `python3 script.py`
    args_to_skip = 0 if os.path.basename(__file__) == sys.argv[0] else 1
    bashdb = BashDb(sys.argv[args_to_skip:])
    sys.exit(bashdb.run())
