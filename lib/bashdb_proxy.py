#!/usr/bin/env python3

"""
Run bashdb in a pty.

This will allow to inject server commands not exposing them
to a user.
"""

import re

from base_proxy import BaseProxy
from stream_filter import StreamFilter


class BashDbProxy(BaseProxy):
    """PTY proxy for bashdb."""

    PROMPT = re.compile(rb'[\r\n]bashdb<\(?\d+\)?> ')
    CSEQ = re.compile(rb'\[[^m]*m')

    def __init__(self):
        """ctor."""
        super().__init__("BashDB")

    def process_handle_command(self, cmd, response):
        """Handle callback for custom commands."""
        self.logger.info("Process handle command %d bytes", len(response))
        # Assuming the prompt occupies the last line
        result = response[(len(cmd) + 1):response.rfind(b'\n')].strip()
        # Get rid of control sequences
        return self.CSEQ.sub(b'', result)

    def filter_command(self, command):
        """Map plugin commands to BashDB commands."""
        tokens = re.split(r'\s+', command.decode('utf-8'))
        if tokens[0] == 'handle-command':
            cmd = command[len('handle-command '):]
            res = self.set_filter(
                StreamFilter(self.PROMPT),
                lambda d: self.process_handle_command(cmd, d))
            return cmd if res else b''
        return command


if __name__ == '__main__':
    BashDbProxy().run()
