#!/usr/bin/env python3

"""
Run bashdb in a pty.

This will allow to inject server commands not exposing them
to a user.
"""

import re
import json

from base_proxy import BaseProxy
from stream_filter import StreamFilter


class BashDbProxy(BaseProxy):
    '''PTY proxy for bashdb.'''
    PROMPT = re.compile(rb'[\r\n]bashdb<\(?\d+\)?> ')
    CSEQ = re.compile(rb'\[[^m]*m')

    def __init__(self):
        super().__init__("BashDB")

    def process_info_breakpoints(self, last_src, response):
        '''Callback for info breakpoints.'''
        # Gdb invokes a custom gdb command implemented in Python.
        # It itself is responsible for sending the processed result
        # to the correct address.
        self.logger.info(f"Process info breakpoints {len(response)} bytes")

        # Filter out the escape sequences used by GDB8
        response = BashDbProxy.CSEQ.sub(b'', response)

        # Select lines in the current file with enabled breakpoints.
        pattern = re.compile(r"([^:]+):(\d+)")
        breaks = {}
        for line in response.decode('utf-8').splitlines():
            try:
                fields = re.split(r"\s+", line)
                if fields[3] == 'y':    # Is enabled?
                    match = pattern.fullmatch(fields[-1])   # file.cpp:line
                    if match and match.group(1) == last_src:
                        line = match.group(2)
                        br_id = fields[0]
                        try:
                            breaks[line].append(br_id)
                        except KeyError:
                            breaks[line] = [br_id]
            except (ValueError, IndexError):
                continue

        return json.dumps(breaks).encode('utf-8')

    def process_handle_command(self, cmd, response):
        '''Callback for custom commands.'''
        self.logger.info(f"Process handle command {len(response)} bytes")
        # Assuming the prompt occupies the last line
        result = response[(len(cmd) + 1):response.rfind(b'\n')].strip()
        # Get rid of control sequences
        return BashDbProxy.CSEQ.sub(b'', result)

    def filter_command(self, command):
        tokens = re.split(r'\s+', command.decode('utf-8'))
        if tokens[0] == 'info-breakpoints':
            last_src = tokens[1]
            res = self.set_filter(
                StreamFilter(BashDbProxy.PROMPT),
                lambda d: self.process_info_breakpoints(last_src, d))
            return b'info breakpoints' if res else b''
        if tokens[0] == 'handle-command':
            cmd = command[len('handle-command '):]
            res = self.set_filter(
                StreamFilter(BashDbProxy.PROMPT),
                lambda d: self.process_handle_command(cmd, d))
            return cmd if res else b''
        return command


if __name__ == '__main__':
    BashDbProxy().run()
