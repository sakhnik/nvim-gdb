#!/usr/bin/env python3

"""
Run GDB in a pty.

This will allow to inject server commands not exposing them
to a user.
"""

import re
import sys

from .impl import Impl
from .stream_filter import StreamFilter


class Gdb(Impl):
    """The PTY proxy for GDB."""

    def __init__(self, argv: [str]):
        """ctor."""
        super().__init__("GDB", argv)
        self.prompt = re.compile(b"\x1a\x1a\x1a")

    def get_prompt(self):
        return self.prompt

    def filter_command(self, command):
        """Prepare a requested command for execution."""
        tokens = re.split(r'\s+', command.decode('utf-8'))
        if tokens[0] == 'handle-command':
            cmd = b'server ' + command[len('handle-command '):]
            res = self.set_filter(
                StreamFilter(self.get_prompt()),
                lambda resp: self.process_handle_command(cmd, resp))
            return cmd if res else b''
        return command


if __name__ == '__main__':
    gdb = Gdb(sys.argv[1:])
    exitcode = gdb.run()
    sys.exit(exitcode)
