#!/usr/bin/env python3

"""
Run LLDB in a pty.

This will allow to inject server commands not exposing them
to a user.
"""

import re

from base_proxy import BaseProxy
from stream_filter import StreamFilter


class LldbProxy(BaseProxy):
    """The PTY proxy for LLDB."""

    CSEQ_STR = rb'\[[^a-zA-Z]*[a-zA-Z]'
    PROMPT = re.compile(rb"\(lldb\) " +
            b"((" + CSEQ_STR + rb")+\(lldb\) (" + CSEQ_STR + rb")+)?")
    CSEQ = re.compile(CSEQ_STR)

    def __init__(self):
        """ctor."""
        super().__init__("LLDB")

    def process_handle_command(self, cmd, response):
        """Process output of custom command."""
        self.logger.info("Process handle command %s bytes", len(response))
        # Assuming the prompt occupies the last line
        result = response[(len(cmd) + 1):response.rfind(b'\n')].strip()
        # Get rid of control sequences
        return self.CSEQ.sub(b'', result)

    def filter_command(self, command):
        """Prepare a requested command for execution."""
        tokens = re.split(r'\s+', command.decode('utf-8'))
        if tokens[0] == 'handle-command':
            cmd = command[len('handle-command '):]
            res = self.set_filter(
                StreamFilter(self.PROMPT),
                lambda resp: self.process_handle_command(cmd, resp))
            return cmd if res else b''
        return command


if __name__ == '__main__':
    LldbProxy().run()
