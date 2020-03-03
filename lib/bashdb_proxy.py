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
    '''PTY proxy for bashdb.'''
    PROMPT = re.compile(rb'[\r\n]bashdb<\(?\d+\)?> ')
    CSEQ = re.compile(rb'\[[^m]*m')

    def __init__(self):
        super().__init__("BashDB")

    def process_handle_command(self, cmd, response):
        '''Callback for custom commands.'''
        self.logger.info(f"Process handle command {len(response)} bytes")
        # Assuming the prompt occupies the last line
        result = response[(len(cmd) + 1):response.rfind(b'\n')].strip()
        # Get rid of control sequences
        return BashDbProxy.CSEQ.sub(b'', result)

    def filter_command(self, command):
        tokens = re.split(r'\s+', command.decode('utf-8'))
        if tokens[0] == 'handle-command':
            cmd = command[len('handle-command '):]
            res = self.set_filter(
                StreamFilter(BashDbProxy.PROMPT),
                lambda d: self.process_handle_command(cmd, d))
            return cmd if res else b''
        return command


if __name__ == '__main__':
    BashDbProxy().run()
