#!/usr/bin/env python3

"""
Run PDB in a pty.

This will allow to inject server commands not exposing them
to a user.
"""

import re

from base_proxy import BaseProxy
from stream_filter import StreamFilter


class PdbProxy(BaseProxy):
    """A proxy for the PDB backend."""

    PROMPT = re.compile(rb"\n\(Pdb\+?\+?\) ")

    def __init__(self):
        """ctor."""
        super().__init__("PDB")

    def process_handle_command(self, cmd, response):
        """Handle callback for a custom command."""
        self.logger.info("Process handle command %s bytes", len(response))
        self.logger.debug("%s", response)
        return response[(len(cmd) + 1):response.rfind(b'\n')].strip()

    def filter_command(self, command):
        """Map plugin commands to Pdb commands."""
        tokens = re.split(r'\s+', command.decode('utf-8'))
        if tokens[0] == 'handle-command':
            cmd = command[len('handle-command '):]
            res = self.set_filter(
                StreamFilter(self.PROMPT),
                lambda d: self.process_handle_command(cmd, d))
            return cmd if res else b''
        # Just pass the original command to highlight it isn't implemented.
        return command


if __name__ == '__main__':
    PdbProxy().run()
