#!/usr/bin/env python3

"""
Run PDB in a pty.

This will allow to inject server commands not exposing them
to a user.
"""

import re
import json

from BaseProxy import BaseProxy


class _PdbFeatures:
    def __init__(self):
        self.app_name = "PDB"
        self.command_begin = b"nvim-gdb-info-breakpoints  "
        self.command_end = b"\n(Pdb) "
        self.last_src = None
        self.alias_set = False  # Was alias defined?

    def ProcessResponse(self, response):
        # Gdb invokes a custom gdb command implemented in Python.
        # It itself is responsible for sending the processed result
        # to the correct address.
        if not self.last_src:
            return

        # Num Type         Disp Enb   Where
        # 1   breakpoint   keep yes   at /tmp/nvim-gdb/test/main.py:8

        breaks = {}
        for line in response.decode('utf-8').splitlines():
            try:
                tokens = re.split(r'\s+', line)
                bid = int(tokens[0])
                if tokens[1] != 'breakpoint':
                    continue
                if tokens[3] != 'yes':
                    continue
                src_line = re.split(r':', tokens[-1])
                if self.last_src == src_line[0]:
                    breaks[src_line[1]] = bid
            except Exception:
                pass

        self.last_src = None
        return json.dumps(breaks).encode('utf-8')

    def FilterCommand(self, command):
        # Map GDB commands to Pdb commands.
        tokens = re.split(r'\s+', command.decode('utf-8'))
        if tokens[0] == 'info-breakpoints':
            self.last_src = tokens[1]
            cmd2 = b''
            if not self.alias_set:
                cmd2 = b'alias nvim-gdb-info-breakpoints break\n'
                self.alias_set = True
            return cmd2 + self.command_begin + b'\n'
        # Just pass the original command to highlight it isn't implemented.
        return command


if __name__ == '__main__':
    BaseProxy.Create(_PdbFeatures())
