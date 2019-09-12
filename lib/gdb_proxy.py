#!/usr/bin/env python3

"""
Run GDB in a pty.

This will allow to inject server commands not exposing them
to a user.
"""

import re
import json
import os

from base_proxy import BaseProxy
from stream_filter import StreamFilter


class GdbProxy(BaseProxy):
    '''The PTY proxy for GDB.'''

    PROMPT = re.compile(b"\x1a\x1a\x1a")
    CSEQ = re.compile(rb'\[[^m]*m')

    def __init__(self):
        super().__init__("GDB")

    def process_info_breakpoints(self, last_src, response):
        '''Handle response from info breakpoints.'''
        # Gdb invokes a custom gdb command implemented in Python.
        # It itself is responsible for sending the processed result
        # to the correct address.
        self.log("Process info breakpoints %d bytes" % len(response))

        # Filter out the escape sequences used by GDB8
        response = GdbProxy.CSEQ.sub(b'', response)

        # Select lines in the current file with enabled breakpoints.
        pattern = re.compile(r"([^:]+):(\d+)")
        breaks = {}
        for line in response.decode('utf-8').splitlines():
            try:
                fields = re.split(r"\s+", line)
                if fields[3] == 'y':    # Is enabled?
                    match = pattern.fullmatch(fields[-1])   # file.cpp:line
                    if match:
                        is_end_match = last_src.endswith(match.group(1))
                        is_end_match_full_path = \
                            last_src.endswith(os.path.realpath(match.group(1)))
                        if (match and (is_end_match or is_end_match_full_path)):
                            line = match.group(2)
                            br_id = float(fields[0])
                            try:
                                breaks[line].append(br_id)
                            except KeyError:
                                breaks[line] = [br_id]
            except IndexError:
                continue
            except ValueError as ex:
                self.log('Exception: {}'.format(str(ex)))

        return json.dumps(breaks).encode('utf-8')

    def process_handle_command(self, cmd, response):
        '''Process output of custom command.'''
        self.log("Process handle command %d bytes" % len(response))
        # Assuming the prompt occupies the last line
        result = response[(len(cmd) + 1):response.rfind(b'\n')].strip()
        # Get rid of control sequences
        return GdbProxy.CSEQ.sub(b'', result)

    def filter_command(self, command):
        tokens = re.split(r'\s+', command.decode('utf-8'))
        if tokens[0] == 'info-breakpoints':
            last_src = tokens[1]
            res = self.set_filter(
                StreamFilter(GdbProxy.PROMPT),
                lambda resp: self.process_info_breakpoints(last_src, resp))
            return b'server info breakpoints' if res else b''
        if tokens[0] == 'handle-command':
            cmd = b'server ' + command[len('handle-command '):]
            res = self.set_filter(
                StreamFilter(GdbProxy.PROMPT),
                lambda resp: self.process_handle_command(cmd, resp))
            return cmd if res else b''
        return command


if __name__ == '__main__':
    GdbProxy().run()
