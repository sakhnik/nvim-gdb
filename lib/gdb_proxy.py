#!/usr/bin/env python3

"""
Run GDB in a pty.

This will allow to inject server commands not exposing them
to a user.
"""

import re

from base_proxy import BaseProxy
from stream_filter import StreamFilter


class GdbProxy(BaseProxy):
    '''The PTY proxy for GDB.'''

    PROMPT = re.compile(b"\x1a\x1a\x1a")
    CSEQ = re.compile(rb'\[[^m]*m')

    def __init__(self):
        super().__init__("GDB")

    def process_handle_command(self, cmd, response):
        '''Process output of custom command.'''
        self.logger.info(f"Process handle command {len(response)} bytes")
        # Assuming the prompt occupies the last line
        result = response[(len(cmd) + 1):response.rfind(b'\n')].strip()
        # Get rid of control sequences
        return GdbProxy.CSEQ.sub(b'', result)

    def filter_command(self, command):
        tokens = re.split(r'\s+', command.decode('utf-8'))
        if tokens[0] == 'handle-command':
            cmd = b'server ' + command[len('handle-command '):]
            res = self.set_filter(
                StreamFilter(GdbProxy.PROMPT),
                lambda resp: self.process_handle_command(cmd, resp))
            return cmd if res else b''
        return command


if __name__ == '__main__':
    GdbProxy().run()
