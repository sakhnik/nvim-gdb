#!/usr/bin/env python3

"""
Run LLDB in a pty.

This will allow to inject server commands not exposing them
to a user.
"""

import re

from base_proxy import BaseProxy
from typing import AnyStr


class LldbProxy(BaseProxy):
    """The PTY proxy for LLDB."""

    def __init__(self):
        """ctor."""
        super().__init__("LLDB")
        self.prompt = re.compile(rb"\(lldb\) (\(lldb\) )?")

    def get_prompt(self) -> re.Pattern[AnyStr]:
        return self.prompt


if __name__ == '__main__':
    LldbProxy().run()
