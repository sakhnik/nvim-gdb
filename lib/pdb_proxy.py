#!/usr/bin/env python3

"""
Run PDB in a pty.

This will allow to inject server commands not exposing them
to a user.
"""

import re
import json

from base_proxy import BaseProxy
from stream_filter import StreamFilter


class PdbProxy(BaseProxy):
    '''A proxy for the PDB backend.'''
    PROMPT = re.compile(rb"\n\(Pdb\) ")

    def __init__(self):
        super().__init__("PDB")

    @staticmethod
    def process_info_breakpoints(last_src, response):
        '''Handler of info breakpoints.'''
        # Gdb invokes a custom gdb command implemented in Python.
        # It itself is responsible for sending the processed result
        # to the correct address.
        if not last_src:
            return None

        # Num Type         Disp Enb   Where
        # 1   breakpoint   keep yes   at /tmp/nvim-gdb/test/main.py:8

        breaks = {}
        for line in response.decode('utf-8').splitlines():
            try:
                tokens = re.split(r'\s+', line)
                bid = tokens[0]
                if tokens[1] != 'breakpoint':
                    continue
                if tokens[3] != 'yes':
                    continue
                src_line = re.split(r':', tokens[-1])
                if last_src == src_line[0]:
                    try:
                        breaks[src_line[1]].append(bid)
                    except KeyError:
                        breaks[src_line[1]] = [bid]
            except (IndexError, ValueError):
                continue

        return json.dumps(breaks).encode('utf-8')

    def process_handle_command(self, cmd, response):
        '''Callback for a custom command.'''
        self.log("Process handle command {} bytes: {}"
                 .format(len(response), response))
        return response[(len(cmd) + 1):response.rfind(b'\n')].strip()

    def filter_command(self, command):
        # Map GDB commands to Pdb commands.
        tokens = re.split(r'\s+', command.decode('utf-8'))
        if tokens[0] == 'info-breakpoints':
            last_src = tokens[1]
            res = self.set_filter(
                StreamFilter(PdbProxy.PROMPT),
                lambda d: self.process_info_breakpoints(last_src, d))
            return b'break' if res else b''
        if tokens[0] == 'handle-command':
            cmd = command[len('handle-command '):]
            res = self.set_filter(
                StreamFilter(PdbProxy.PROMPT),
                lambda d: self.process_handle_command(cmd, d))
            return cmd if res else b''
        # Just pass the original command to highlight it isn't implemented.
        return command


if __name__ == '__main__':
    PdbProxy().run()
