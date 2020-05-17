#!/usr/bin/env python3

"""
Run LLDB in a pty.

This will allow to inject server commands not exposing them
to a user.
"""

import re

from base_proxy import BaseProxy


class LldbProxy(BaseProxy):
    """The PTY proxy for LLDB."""

    def __init__(self):
        """ctor."""
        super().__init__("LLDB")
        self.prompt = re.compile(rb"\(lldb\) " +
            b"((" + self.CSEQ_STR + rb")+\(lldb\) (" + self.CSEQ_STR + rb")+)?")

    def get_prompt(self):
        return self.prompt


if __name__ == '__main__':
    LldbProxy().run()
