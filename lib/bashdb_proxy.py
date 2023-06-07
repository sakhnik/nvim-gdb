#!/usr/bin/env python3

"""
Run bashdb in a pty.

This will allow to inject server commands not exposing them
to a user.
"""

import re
import sys

from proxy_impl import ProxyImpl


class BashDbProxy(ProxyImpl):
    """PTY proxy for bashdb."""

    def __init__(self, argv: [str]):
        """ctor."""
        super().__init__("BashDB", argv)
        self.prompt = re.compile(rb'[\r\n]bashdb<\(?\d+\)?> ')

    def get_prompt(self):
        return self.prompt


if __name__ == '__main__':
    proxy = BashDbProxy(sys.argv[1:])
    exitcode = proxy.run()
    sys.exit(exitcode)
