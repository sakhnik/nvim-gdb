#!/usr/bin/env python3

"""
Run bashdb in a pty.

This will allow to inject server commands not exposing them
to a user.
"""

import re

from base_proxy import BaseProxy


class BashDbProxy(BaseProxy):
    """PTY proxy for bashdb."""

    def __init__(self):
        """ctor."""
        super().__init__("BashDB")
        self.prompt = re.compile(rb'[\r\n]bashdb<\(?\d+\)?> ')

    def get_prompt(self):
        return self.prompt


if __name__ == '__main__':
    BashDbProxy().run()
