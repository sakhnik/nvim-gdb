#!/usr/bin/env python3

"""
Run PDB in a pty.

This will allow to inject server commands not exposing them
to a user.
"""

import re

from base_proxy import BaseProxy


class PdbProxy(BaseProxy):
    """A proxy for the PDB backend."""

    def __init__(self):
        """ctor."""
        super().__init__("PDB")
        self.prompt = re.compile(rb"\(Pdb\+?\+?\) ")

    def get_prompt(self):
        return self.prompt


if __name__ == '__main__':
    PdbProxy().run()
