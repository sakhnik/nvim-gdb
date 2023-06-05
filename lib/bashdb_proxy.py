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

    def __init__(self):
        """ctor."""
        super().__init__("BashDB")
        self.prompt = re.compile(rb'[\r\n]bashdb<\(?\d+\)?> ')

    def get_prompt(self):
        return self.prompt


if __name__ == '__main__':
    proxy = BashDbProxy()
    proxy.run()
    sys.exit(proxy.exitstatus)
